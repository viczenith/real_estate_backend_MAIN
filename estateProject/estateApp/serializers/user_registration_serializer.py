from rest_framework import serializers
from estateApp.models import AdminUser, ClientUser, MarketerUser, CustomUser

class UserRegistrationSerializer(serializers.Serializer):
    full_name = serializers.CharField()
    password = serializers.CharField(write_only=True)
    address = serializers.CharField()
    phone = serializers.CharField()
    email = serializers.EmailField()
    date_of_birth = serializers.DateField(required=False)
    role = serializers.ChoiceField(choices=CustomUser.ROLE_CHOICES)
    marketer_id = serializers.IntegerField(required=False, allow_null=True, write_only=True)

    def validate(self, data):
        role = data.get("role")
        marketer_id = data.get("marketer_id")

        if role == "client":
            if not marketer_id:
                raise serializers.ValidationError({"marketer_id": "Marketer is required for client users."})
            try:
                marketer = CustomUser.objects.get(id=marketer_id, role="marketer")
                data["marketer"] = marketer
            except CustomUser.DoesNotExist:
                raise serializers.ValidationError({"marketer_id": "Invalid marketer ID."})
        elif marketer_id:
            raise serializers.ValidationError({"marketer_id": "Only clients should have a marketer."})

        return data

    def create(self, validated_data):
        role = validated_data.pop("role")
        marketer = validated_data.pop("marketer", None)
        password = validated_data.pop("password")

        if role == "admin":
            user = AdminUser(**validated_data)
        elif role == "client":
            user = ClientUser(**validated_data, marketer=marketer)
        elif role == "marketer":
            user = MarketerUser(**validated_data)
        else:
            raise serializers.ValidationError({"role": "Invalid role"})

        user.set_password(password)
        user.save()
        return user