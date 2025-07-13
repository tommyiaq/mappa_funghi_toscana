# Mappa Funghi Toscana - Restructured

This Flutter app has been restructured to follow better coding practices and improve maintainability.

## Project Structure

```
lib/
├── main.dart                    # Entry point - minimal, clean
├── constants/
│   └── app_constants.dart       # Centralized configuration
├── controllers/
│   └── map_controller.dart      # State management (optional)
├── models/
│   └── cloud_spot.dart         # Data models
├── pages/
│   ├── home_page.dart          # Home page wrapper
│   └── archivio_page.dart      # Archive page wrapper
├── services/
│   └── csv_service.dart        # Data services
├── utils/
│   ├── date_utils.dart         # Date utilities
│   ├── marker_utils.dart       # Map marker utilities
│   └── cloud_utils.dart        # Cloud utilities
└── widgets/
    ├── main_scaffold.dart      # Main navigation scaffold
    ├── map_view.dart           # Main map widget
    ├── mushroom_selector.dart  # Mushroom type selector
    ├── day_selector.dart       # Day selection dropdown
    ├── date_range_selector.dart# Date range picker
    ├── gradient_cloud_image.dart# Cloud overlay image provider
    └── rainfall_webview.dart   # Existing webview widget
```

## Key Improvements

### 1. **Separation of Concerns**
- **Pages**: Simple wrappers that compose widgets
- **Widgets**: Reusable UI components with single responsibilities
- **Services**: Data access and business logic
- **Utils**: Helper functions and utilities
- **Constants**: Centralized configuration

### 2. **Modular Widget Architecture**
- `MapView`: Main map container with core logic
- `MushroomSelector`: Reusable mushroom type selection
- `DaySelector`: Day selection dropdown
- `DateRangeSelector`: Date range picker with validation
- `GradientCloudImage`: Isolated cloud overlay rendering

### 3. **Centralized Configuration**
- All magic numbers and strings moved to `AppConstants`
- Colors, dimensions, delays, and API endpoints in one place
- Easy to modify app-wide settings

### 4. **Better State Management**
- Clean separation between UI state and business logic
- Debounced user interactions
- Proper async handling with mounted checks
- Optional controller pattern for complex state management

### 5. **Improved Code Organization**
- Single responsibility principle
- Easier testing and debugging
- Better code reusability
- Cleaner imports and dependencies

## Benefits of This Structure

1. **Maintainability**: Changes to specific features are isolated to relevant files
2. **Testability**: Individual widgets and services can be tested separately
3. **Reusability**: Components can be easily reused across different parts of the app
4. **Scalability**: Easy to add new features without affecting existing code
5. **Developer Experience**: Code is easier to navigate and understand

## Migration Notes

- The main.dart file is now minimal (20 lines vs 500+ lines)
- All business logic has been moved to appropriate service/utility files
- UI components are properly encapsulated
- Configuration is centralized and easily modifiable

## Next Steps (Optional Improvements)

1. **Add Provider/Riverpod**: For more complex state management
2. **Add Navigation**: Implement proper routing if app grows
3. **Add Error Handling**: Centralized error handling and user feedback
4. **Add Logging**: Structured logging for debugging
5. **Add Tests**: Unit and widget tests for all components
6. **Add Documentation**: API documentation and inline comments
