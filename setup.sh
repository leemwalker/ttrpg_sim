#!/bin/bash
echo "Starting TTRPG Sim Setup..."

# 1. Install Dependencies
echo "Running flutter pub get..."
flutter pub get

# 2. Generate Code (Freezed, Drift, Riverpod)
echo "Running build_runner (this may take a minute)..."
dart run build_runner build --delete-conflicting-outputs

echo "Setup Complete! You can now run 'flutter run'."
