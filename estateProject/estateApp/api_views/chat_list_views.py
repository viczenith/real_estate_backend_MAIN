# from django.contrib.auth import get_user_model
# from django.db.models import Count, Max, Q
# from rest_framework.decorators import api_view, permission_classes
# from rest_framework.permissions import IsAuthenticated, IsAdminUser
# from rest_framework.response import Response
# from estateApp.models import Message
# from estateApp.serializers.chat_list_serializer import ClientChatSerializer

# User = get_user_model()

# @api_view(['GET'])
# @permission_classes([IsAuthenticated, IsAdminUser])
# def admin_client_chat_list(request):
#     admin = request.user

#     senders = (
#         Message.objects
#         .filter(recipient=admin)
#         .values('sender')
#         .annotate(
#             last_date=Max('date_sent'),
#             unread_count=Count('id', filter=Q(is_read=False))
#         )
#         .order_by('-last_date')
#     )

#     data = []
#     for entry in senders:
#         uid   = entry['sender']
#         try:
#             client = User.objects.get(pk=uid)
#         except User.DoesNotExist:
#             continue
#         data.append({
#             'id':            client.id,
#             'full_name':     client.get_full_name() or client.username,
#             'last_message':  entry['last_date'],
#             'unread_count':  entry['unread_count'],
#         })

#     return Response(ClientChatSerializer(data, many=True).data)



# from django.db.models import Q
# from rest_framework.decorators import api_view, permission_classes
# from rest_framework.permissions import IsAuthenticated, IsAdminUser
# from rest_framework.parsers import MultiPartParser, FormParser
# from rest_framework.response import Response
# from rest_framework import status

# from estateApp.models import Message
# from estateApp.serializers.message_serializer import MessageSerializer, MessageCreateSerializer

# @api_view(['GET','POST'])
# @permission_classes([IsAuthenticated, IsAdminUser])
# def admin_client_chat_detail(request, client_id):
#     """
#     GET:   list all messages between admin(request.user) and client_id
#     POST:  send a new message from admin to client
#     """
#     admin = request.user

#     # ensure client exists
#     from django.contrib.auth import get_user_model
#     User = get_user_model()
#     try:
#         client = User.objects.get(pk=client_id)
#     except User.DoesNotExist:
#         return Response({'detail':'Client not found'}, status=404)

#     if request.method == 'GET':
#         qs = Message.objects.filter(
#             Q(sender=admin, recipient=client) |
#             Q(sender=client, recipient=admin)
#         ).order_by('date_sent')
#         # mark client→admin messages as read
#         qs.filter(sender=client, recipient=admin, is_read=False).update(is_read=True)
#         return Response(MessageSerializer(qs, many=True).data)

#     # POST
#     serializer = MessageCreateSerializer(data=request.data)
#     if not serializer.is_valid():
#         return Response(serializer.errors, status=400)

#     msg = serializer.save(
#         sender=admin,
#         recipient=client,
#         status='sent'
#     )
#     return Response(MessageSerializer(msg).data, status=201)


from rest_framework import generics
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.contrib.auth import get_user_model
from estateApp.models import Message
from estateApp.serializers.chat_list_serializer import ClientChatSerializer
from django.db.models import Count, Max, Q, OuterRef, Subquery

User = get_user_model()

class ClientChatListView(generics.ListAPIView):
    serializer_class = ClientChatSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get_queryset(self):
        admin = self.request.user
        
        # Get last message content per client
        last_msg_content = Message.objects.filter(
            Q(sender=OuterRef('pk'), recipient=admin) |
            Q(sender=admin, recipient=OuterRef('pk'))
        ).order_by('-date_sent').values('content')[:1]

        # Get last message timestamp per client
        last_msg_time = Message.objects.filter(
            Q(sender=OuterRef('pk'), recipient=admin) |
            Q(sender=admin, recipient=OuterRef('pk'))
        ).order_by('-date_sent').values('date_sent')[:1]

        clients = User.objects.filter(
            Q(sent_messages__recipient=admin) | 
            Q(received_messages__sender=admin)
        ).annotate(
            last_message=Subquery(last_msg_content),
            timestamp=Subquery(last_msg_time),
            unread_count=Count('sent_messages', 
                filter=Q(sent_messages__recipient=admin) & 
                       Q(sent_messages__is_read=False))
        ).distinct().order_by('-timestamp')

        return clients.exclude(timestamp__isnull=True)


