from rest_framework import status, permissions
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.generics import ListAPIView, CreateAPIView, DestroyAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from django.db.models import Q
from django.utils import timezone
from datetime import timedelta
from django.template.loader import render_to_string

from estateApp.models import Message, CustomUser
from DRF.shared_drf.push_service import send_chat_message_deleted_push
from DRF.clients.serializers.chat_serializers import (
    MessageSerializer,
    MessageCreateSerializer,
    MessageListSerializer,
    ChatUnreadCountSerializer
)


SUPPORT_ROLES = ('admin', 'support')


class ChatMessagePagination(PageNumberPagination):
    """Custom pagination for chat messages"""
    page_size = 50
    page_size_query_param = 'page_size'
    max_page_size = 100


class ClientChatListAPIView(ListAPIView):
    """
    GET: Retrieve all messages in the conversation between client and admin
    
    Query params:
    - last_msg_id: Get only messages after this ID (for polling/real-time updates)
    - page: Page number for pagination
    - page_size: Number of messages per page (default: 50, max: 100)
    """
    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MessageListSerializer
    pagination_class = ChatMessagePagination
    
    def get_queryset(self):
        user = self.request.user
        
        # Mark all unread messages from admin as read
        Message.objects.filter(
            sender__role__in=SUPPORT_ROLES,
            recipient=user,
            is_read=False
        ).update(is_read=True, status='read')
        
        # Get conversation with any admin
        queryset = Message.objects.filter(
            Q(sender=user, recipient__role__in=SUPPORT_ROLES) |
            Q(sender__role__in=SUPPORT_ROLES, recipient=user)
        ).select_related('sender', 'recipient').order_by('date_sent')
        
        # If polling with last_msg_id, only return newer messages
        last_msg_id = self.request.query_params.get('last_msg_id')
        if last_msg_id:
            try:
                last_msg_id = int(last_msg_id)
                queryset = queryset.filter(id__gt=last_msg_id)
            except (ValueError, TypeError):
                pass
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        
        # Always disable pagination for chat to get all messages in consistent format
        # Chat messages should load all at once for better UX
        serializer = self.get_serializer(queryset, many=True)
        
        # Generate HTML for each message using the template
        messages_html = ""
        for msg in queryset:
            messages_html += render_to_string('client_side/chat_message.html', {
                'msg': msg, 
                'request': request
            })
        
        # Return consistent structure expected by Flutter client
        return Response({
            'count': queryset.count(),
            'messages': serializer.data,  # Flutter expects 'messages' key
            'messages_html': messages_html
        })


class ClientChatDetailAPIView(APIView):
    """
    GET: Retrieve a single message by ID
    """
    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, pk):
        try:
            message = Message.objects.select_related('sender', 'recipient').get(
                Q(sender=request.user) | Q(recipient=request.user),
                pk=pk
            )
        except Message.DoesNotExist:
            return Response(
                {'error': 'Message not found or you do not have permission to view it.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        serializer = MessageSerializer(message, context={'request': request})
        return Response(serializer.data)


class ClientChatSendAPIView(CreateAPIView):
    """
    POST: Send a new message to admin
    
    Body (multipart/form-data or JSON):
    - content: Message text (optional if file is provided)
    - file: File attachment (optional)
    - message_type: 'complaint', 'enquiry', or 'compliment' (default: 'enquiry')
    - reply_to: Message ID to reply to (optional)
    """
    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MessageCreateSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        
        if not serializer.is_valid():
            return Response(
                {'success': False, 'errors': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create the message
        message = serializer.save()
        
        # Return full message details
        response_serializer = MessageSerializer(message, context={'request': request})
        
        # Generate HTML for the new message
        message_html = render_to_string('client_side/chat_message.html', {
            'msg': message,
            'request': request,
        })
        
        return Response({
            'success': True,
            'message': response_serializer.data,
            'message_html': message_html
        }, status=status.HTTP_201_CREATED)


class ClientChatDeleteAPIView(DestroyAPIView):
    """
    DELETE: Delete a message (only within 30 minutes of sending)
    """
    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Message.objects.filter(sender=self.request.user)
    
    def destroy(self, request, *args, **kwargs):
        try:
            message = self.get_queryset().get(pk=kwargs['pk'])
        except Message.DoesNotExist:
            return Response(
                {'success': False, 'error': 'Message not found or you do not have permission to delete it.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if message is older than 30 minutes
        time_limit = timezone.now() - timedelta(minutes=30)
        if message.date_sent < time_limit:
            return Response(
                {'success': False, 'error': 'You can only delete messages within 30 minutes of sending.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        message.delete()
        return Response({
            'success': True,
            'message': 'Message deleted successfully.'
        }, status=status.HTTP_200_OK)


class ClientChatDeleteForEveryoneAPIView(APIView):
    """Soft-delete a message for everyone within 24 hours of sending."""

    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        message_id = request.data.get('message_id')

        if not message_id:
            return Response(
                {'success': False, 'error': 'message_id is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            message_id = int(message_id)
        except (TypeError, ValueError):
            return Response(
                {'success': False, 'error': 'Invalid message_id supplied.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            message = Message.objects.select_related('sender').get(pk=message_id)
        except Message.DoesNotExist:
            return Response(
                {'success': False, 'error': 'Message not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if message.sender != request.user:
            return Response(
                {'success': False, 'error': 'You can only delete your own messages.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if message.deleted_for_everyone:
            serializer = MessageSerializer(message, context={'request': request})
            return Response({'success': True, 'message': serializer.data})

        time_limit = timezone.now() - timedelta(hours=24)
        if message.date_sent < time_limit:
            return Response(
                {
                    'success': False,
                    'error': 'You can only delete messages within 24 hours of sending.',
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        message.deleted_for_everyone = True
        message.deleted_for_everyone_at = timezone.now()
        message.deleted_for_everyone_by = request.user
        message.save(update_fields=[
            'deleted_for_everyone',
            'deleted_for_everyone_at',
            'deleted_for_everyone_by',
        ])

        # Notify conversation participants so their clients can update immediately
        send_chat_message_deleted_push(message)

        serializer = MessageSerializer(message, context={'request': request})
        return Response({'success': True, 'message': serializer.data})


class ClientChatUnreadCountAPIView(APIView):
    """
    GET: Get the count of unread messages from admin
    """
    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Count unread messages from admin
        unread_count = Message.objects.filter(
            sender__role__in=SUPPORT_ROLES,
            recipient=user,
            is_read=False
        ).count()
        
        # Get the last message in conversation
        last_message = Message.objects.filter(
            Q(sender=user, recipient__role__in=SUPPORT_ROLES) |
            Q(sender__role__in=SUPPORT_ROLES, recipient=user)
        ).select_related('sender').order_by('-date_sent').first()
        
        data = {
            'unread_count': unread_count,
            'last_message': MessageListSerializer(
                last_message,
                context={'request': request}
            ).data if last_message else None
        }
        
        return Response(data)


class ClientChatMarkAsReadAPIView(APIView):
    """
    POST: Mark specific messages or all messages as read
    
    Body (JSON):
    - message_ids: List of message IDs to mark as read (optional)
    - mark_all: Boolean to mark all unread messages as read (default: false)
    """
    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        user = request.user
        message_ids = request.data.get('message_ids', [])
        mark_all = request.data.get('mark_all', False)
        
        if mark_all:
            # Mark all unread messages from admin as read
            updated_count = Message.objects.filter(
                sender__role__in=SUPPORT_ROLES,
                recipient=user,
                is_read=False
            ).update(is_read=True, status='read')
            
            return Response({
                'success': True,
                'message': f'{updated_count} message(s) marked as read.'
            })
        
        elif message_ids:
            # Mark specific messages as read
            updated_count = Message.objects.filter(
                id__in=message_ids,
                sender__role__in=SUPPORT_ROLES,
                recipient=user,
                is_read=False
            ).update(is_read=True, status='read')
            
            return Response({
                'success': True,
                'message': f'{updated_count} message(s) marked as read.'
            })
        
        else:
            return Response(
                {'success': False, 'error': 'Please provide message_ids or set mark_all to true.'},
                status=status.HTTP_400_BAD_REQUEST
            )


class ClientChatPollAPIView(APIView):
    """
    GET: Poll for new messages (lightweight endpoint for real-time updates)
    
    Query params:
    - last_msg_id: Get only messages after this ID
    """
    authentication_classes = [TokenAuthentication, SessionAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        last_msg_id = request.query_params.get('last_msg_id', 0)
        
        try:
            last_msg_id = int(last_msg_id)
        except (ValueError, TypeError):
            last_msg_id = 0
        
        # Get new messages
        new_messages = Message.objects.filter(
            Q(sender=user, recipient__role__in=SUPPORT_ROLES) |
            Q(sender__role__in=SUPPORT_ROLES, recipient=user),
            id__gt=last_msg_id
        ).select_related('sender').order_by('date_sent')
        
        # Mark new messages from admin as read
        Message.objects.filter(
            id__in=[msg.id for msg in new_messages],
            sender__role__in=SUPPORT_ROLES,
            recipient=user,
            is_read=False
        ).update(is_read=True, status='read')
        
        serializer = MessageListSerializer(
            new_messages,
            many=True,
            context={'request': request}
        )
        
        # Generate HTML for new messages using the template
        new_messages_html = ""
        for msg in new_messages:
            new_messages_html += render_to_string('client_side/chat_message.html', {
                'msg': msg,
                'request': request
            })
        
        # Get updated status for all user's sent messages
        updated_statuses = []
        if new_messages.exists():
            user_messages = Message.objects.filter(
                sender=user,
                id__lte=last_msg_id + len(new_messages)
            ).values('id', 'status')
            updated_statuses = list(user_messages)
        
        return Response({
            'new_messages': serializer.data,
            'count': new_messages.count(),
            'updated_statuses': updated_statuses,
            'new_messages_html': new_messages_html
        })
