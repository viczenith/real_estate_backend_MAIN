from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from estateApp.models import UserDeviceToken
from DRF.clients.serializers.device_token_serializers import DeviceTokenSerializer


class DeviceTokenRegisterView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = DeviceTokenSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        instance = serializer.save()

        response_serializer = DeviceTokenSerializer(instance, context={"request": request})
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)

    def delete(self, request, *args, **kwargs):
        token = request.data.get("token") or request.query_params.get("token")
        if not token:
            return Response(
                {"detail": "Token is required to delete a device registration."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        deleted, _ = UserDeviceToken.objects.filter(user=request.user, token=token).delete()
        if deleted == 0:
            return Response(
                {"detail": "Specified token was not found for this user."},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(status=status.HTTP_204_NO_CONTENT)


class DeviceTokenListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        queryset = UserDeviceToken.objects.filter(user=request.user).order_by("-last_seen")
        serializer = DeviceTokenSerializer(queryset, many=True, context={"request": request})
        return Response(serializer.data)
