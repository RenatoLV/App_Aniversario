# JNI entry points are accessed by native code.
-keep class org.godotengine.** { *; }
# Godot also calls Java methods from C++ by name. Keeping only native methods
# does not preserve those callbacks (debug builds do not run R8).
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
