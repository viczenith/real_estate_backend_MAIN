from rest_framework.permissions import BasePermission

class IsRecipient(BasePermission):
    """
    Object-level permission to allow only the recipient to access a UserNotification instance.
    """
    def has_object_permission(self, request, view, obj):
        # obj is a UserNotification instance
        return obj.user_id == request.user.id


from rest_framework import permissions

class IsClientUser(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return getattr(user, 'role', None) == 'client'
    
    
