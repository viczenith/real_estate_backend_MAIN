from estateApp.models import CustomUser

class EmailBackend:
    def authenticate(self, request=None, username=None, password=None, email=None):
        try:
            # Support both 'username' and 'email' parameters
            lookup_email = email or username
            if not lookup_email or not password:
                return None
            
            print(f"[EmailBackend] Attempting to authenticate with email: {lookup_email}")
            user = CustomUser.objects.get(email=lookup_email)
            print(f"[EmailBackend] User found: {user.email}")
            
            if user.check_password(password):
                print(f"[EmailBackend] Password correct for {user.email}")
                return user
            else:
                print(f"[EmailBackend] Password incorrect for {user.email}")
                return None
        except CustomUser.DoesNotExist:
            print(f"[EmailBackend] User with email {lookup_email} not found")
            return None
        except Exception as e:
            print(f"[EmailBackend] Error during authentication: {str(e)}")
            return None
    
    def get_user(self, user_id):
        try:
            return CustomUser.objects.get(pk=user_id)
        except CustomUser.DoesNotExist:
            return None
