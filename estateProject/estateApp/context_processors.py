from estateApp.models import *
from django.db.models import Max, Count, Subquery, OuterRef
from django.utils import timezone
from django.urls import reverse


def chat_notifications(request):
    context = {}
    if not request.user.is_authenticated:
        return context
        
    if request.user.role == 'admin':
        # Aggregate across ALL admins so any admin sees all client unread
        total = Message.objects.filter(
            recipient__role='admin',
            is_read=False
        ).count()

        context.update({
            'total_unread_messages': total,
            'total_unread_count': total,
        })

        # Get unique clients with unread messages to ANY admin and their counts
        unread_clients = (CustomUser.objects
            .filter(
                role='client',
                sent_messages__recipient__role='admin',
                sent_messages__is_read=False,
            )
            .annotate(
                last_message=Max('sent_messages__date_sent'),
                unread_count=Count('sent_messages'),
                last_content=Subquery(
                    Message.objects.filter(
                        sender=OuterRef('pk'),
                        recipient__role='admin'
                    ).order_by('-date_sent').values('content')[:1]
                ),
                last_file=Subquery(
                    Message.objects.filter(
                        sender=OuterRef('pk'),
                        recipient__role='admin'
                    ).order_by('-date_sent').values('file')[:1]
                )
            )
            .distinct()
            .order_by('-last_message')
        )

        context.update({
            'client_count': unread_clients.count(),
            'unread_clients': unread_clients[:5],
        })

        # Include marketers with unread messages to ANY admin for header dropdown
        unread_marketers = (CustomUser.objects
            .filter(
                role='marketer',
                sent_messages__recipient__role='admin',
                sent_messages__is_read=False,
            )
            .annotate(
                last_message=Max('sent_messages__date_sent'),
                unread_count=Count('sent_messages'),
                last_content=Subquery(
                    Message.objects.filter(
                        sender=OuterRef('pk'),
                        recipient__role='admin'
                    ).order_by('-date_sent').values('content')[:1]
                ),
                last_file=Subquery(
                    Message.objects.filter(
                        sender=OuterRef('pk'),
                        recipient__role='admin'
                    ).order_by('-date_sent').values('file')[:1]
                )
            )
            .distinct()
            .order_by('-last_message')
        )

        context.update({
            'marketers': unread_marketers[:5],
            'marketers_unread_count': unread_marketers.count(),
        })
    else:
        # Client/Marketer view logic
        admin_user = CustomUser.objects.filter(role='admin').first()

        unread_from_admin = Message.objects.filter(
            sender__role='admin',
            recipient=request.user,
            is_read=False
        )
        unread_count = unread_from_admin.count()
        context['global_message_count'] = unread_count
        context['unread_chat_count'] = unread_count
        context['recent_admin_messages'] = list(unread_from_admin.order_by('-date_sent')[:5]) if admin_user else []
        context['unread_admin_count'] = unread_count

        # Pending allocations retained for dashboard usage
        context['pending_allocations'] = PlotAllocation.objects.filter(
            payment_type='part',
            plot_number__isnull=True
        ).count()

    return context


# NOTIFICATION
def user_notifications(request):
    if not request.user.is_authenticated:
        return {}

    unread = (UserNotification.objects
        .filter(user=request.user, read=False)
        .select_related('notification')[:10]
    )

    return {
        'unread_notifications': unread,
        'unread_notifications_count': unread.count(),
    }

# DASHBOARD URL REVERSAL
def dashboard_url(request):
    if not request.user.is_authenticated:
        return {'home_url': reverse('login')}
    
    role = getattr(request.user, 'role', None)
    if role == 'admin':
        url = reverse('admin-dashboard')
    elif role == 'client':
        url = reverse('client-dashboard')
    elif role == 'marketer':
        url = reverse('marketer-dashboard')
    else:
        url = reverse('login')
    return {'home_url': url}

