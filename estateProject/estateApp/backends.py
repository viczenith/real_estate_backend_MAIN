from estateApp.models import CustomUser

class EmailBackend:
    def authenticate(self, request, username=None, password=None):
        try:
            # Replace 'User' with 'CustomUser'
            user = CustomUser.objects.get(email=username)
            if user.check_password(password):
                return user
        except CustomUser.DoesNotExist:
            return None
