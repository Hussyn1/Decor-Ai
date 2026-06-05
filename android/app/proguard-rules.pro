# Suppress warnings for missing Sceneform classes referenced at runtime
-dontwarn com.google.ar.sceneform.animation.AnimationEngine
-dontwarn com.google.ar.sceneform.animation.AnimationLibraryLoader
-dontwarn com.google.ar.sceneform.assets.Loader
-dontwarn com.google.ar.sceneform.assets.ModelData
-dontwarn com.google.devtools.build.android.desugar.runtime.ThrowableExtension

# Keep all ARCore / Sceneform classes
-keep class com.google.ar.** { *; }
-keep class com.google.ar.sceneform.** { *; }
