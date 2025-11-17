from django.shortcuts import redirect

class AdminAccessMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, view_func, view_args, view_kwargs):
        if request.resolver_match and request.resolver_match.url_name == 'send-notification':
            if not request.user.is_authenticated or not request.user.is_staff:
                return redirect('login')
