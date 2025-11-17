from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from estateApp.serializers.user_registration_serializer import UserRegistrationSerializer
from django.db import IntegrityError

# @api_view(['POST'])
# @permission_classes([AllowAny])
# def admin_user_registration(request):
#     serializer = UserRegistrationSerializer(data=request.data)
#     if serializer.is_valid():
#         user = serializer.save()
#         return Response({
#             "message": f"{user.role.capitalize()} registered successfully!",
#             "user_id": user.id
#         }, status=status.HTTP_201_CREATED)
#     return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def admin_user_registration(request):
    serializer = UserRegistrationSerializer(data=request.data)
    try:
        if serializer.is_valid():
            user = serializer.save()
            return Response({
                "message": f"{user.role.capitalize()} registered successfully!",
                "user_id": user.id
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    except IntegrityError as e:
        # Check if the error is related to the email field being unique
        if 'email' in str(e):
            return Response({"error": "Email already Registered."}, status=status.HTTP_400_BAD_REQUEST)
        # Catch other integrity errors
        return Response({"error": "Database integrity error occurred."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    except Exception as e:
        # Catch other unexpected errors
        return Response({"error": f"An error occurred: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



        