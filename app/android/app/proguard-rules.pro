# JNI entry points are accessed by native code.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
