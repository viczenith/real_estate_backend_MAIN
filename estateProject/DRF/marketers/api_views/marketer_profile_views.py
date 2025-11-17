from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework import serializers as drf_serializers
from django.shortcuts import get_object_or_404
from django.db.models import Sum
from decimal import Decimal
from datetime import date

from DRF.marketers.serializers.marketer_profile_serializers import MarketerProfileSerializer, SmallMarketerSerializer
from estateApp.models import *


class IsMarketer(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        # allow staff/admins too so admin pages can view
        if getattr(request.user, 'is_staff', False) or getattr(request.user, 'is_superuser', False):
            return True
        return getattr(request.user, 'role', '') == 'marketer'


class MarketerProfileView(APIView):
    """
    GET: returns the marketer's profile + performance + leaderboard data.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated, IsMarketer)

    def get(self, request, *args, **kwargs):
        user = request.user
        try:
            marketer = MarketerUser.objects.get(pk=user.id)
        except MarketerUser.DoesNotExist:
            return Response({'detail': 'Marketer profile not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = MarketerProfileSerializer(marketer, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class MarketerProfileUpdateView(APIView):
    """
    POST multipart/form-data to update marketer fields (about, company, job, country, profile_image).
    """
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated, IsMarketer)
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, *args, **kwargs):
        user = request.user
        try:
            marketer = MarketerUser.objects.get(pk=user.id)
        except MarketerUser.DoesNotExist:
            return Response({'detail': 'Marketer not found'}, status=status.HTTP_404_NOT_FOUND)

        updatable = ['about', 'company', 'job', 'country']
        for f in updatable:
            if f in request.data:
                setattr(marketer, f, request.data.get(f) or None)

        if 'profile_image' in request.FILES:
            marketer.profile_image = request.FILES['profile_image']

        marketer.save()
        serializer = MarketerProfileSerializer(marketer, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class ChangePasswordSerializer(drf_serializers.Serializer):
    current_password = drf_serializers.CharField(required=True)
    new_password = drf_serializers.CharField(required=True, min_length=6)

class MarketerChangePasswordView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated, IsMarketer)

    def post(self, request, *args, **kwargs):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        current = serializer.validated_data['current_password']
        new = serializer.validated_data['new_password']

        if not user.check_password(current):
            return Response({'detail': 'Current password is incorrect.'}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new)
        user.save()
        return Response({'detail': 'Password updated successfully.'}, status=status.HTTP_200_OK)


class MarketerTransactionsView(APIView):
    """
    GET: list transactions where the marketer is the assigned marketer.
    This supports the "Deals" listing for a marketer dashboard.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated, IsMarketer)

    def get(self, request, *args, **kwargs):
        user = request.user
        qs = Transaction.objects.filter(marketer_id=user.id).select_related('client', 'allocation__estate', 'allocation__plot_size_unit').prefetch_related('payment_records')
        # You can reuse the TransactionSerializer you already have in client side to return flattened payloads.
        # import here to avoid circular imports:
        from DRF.clients.serializers.client_profile_serializer import TransactionSerializer
        serializer = TransactionSerializer(qs, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

