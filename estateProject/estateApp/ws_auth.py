from __future__ import annotations

from urllib.parse import parse_qs

from channels.auth import AuthMiddlewareStack
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.contrib.auth import get_user_model
from django.utils.functional import LazyObject

from rest_framework.authtoken.models import Token

User = get_user_model()


@database_sync_to_async
def _get_user(token_key: str):
    try:
        token = Token.objects.select_related('user').get(key=token_key)
        return token.user
    except Token.DoesNotExist:
        return AnonymousUser()


class TokenAuthMiddleware:
    """Simple token authentication for WebSocket connections."""

    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode()
        params = parse_qs(query_string)
        token_list = params.get('token') or params.get('auth')

        user = AnonymousUser()
        if token_list:
            token_key = token_list[0]
            user = await _get_user(token_key)

        scope['user'] = user
        return await self.inner(scope, receive, send)


def TokenAuthMiddlewareStack(inner):
    return TokenAuthMiddleware(AuthMiddlewareStack(inner))
