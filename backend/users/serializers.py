from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import FavoriteTrack, PromptHistory, UserPreference

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'profile_picture', 'bio',
                  'is_spotify_connected', 'is_staff', 'is_superuser',
                  'preferred_artists', 'created_at']
        read_only_fields = ['id', 'created_at', 'is_spotify_connected', 'is_staff', 'is_superuser']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'confirm_password']

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError("Passwords do not match.")
        return data

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
        )
        return user


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, min_length=6)
    confirm_new_password = serializers.CharField(required=True)

    def validate(self, data):
        if data['new_password'] != data['confirm_new_password']:
            raise serializers.ValidationError("New passwords do not match.")
        return data


class FavoriteTrackSerializer(serializers.ModelSerializer):
    class Meta:
        model = FavoriteTrack
        fields = '__all__'
        read_only_fields = ['user', 'added_at']


class PromptHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = PromptHistory
        fields = '__all__'
        read_only_fields = ['user', 'created_at']


class UserPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserPreference
        fields = '__all__'
        read_only_fields = ['user']
