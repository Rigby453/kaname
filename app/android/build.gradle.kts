allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Некоторые плагины (file_picker 8.x) собираются под compileSdk 34, а их зависимость
// flutter_plugin_android_lifecycle требует ≥ 36 (Android 16 / API 36). Принудительно
// поднимаем compileSdk до 36 для всех Android-подмодулей. Через reflection, чтобы не
// тянуть импорт AGP-классов в корневой buildscript. Регистрируем afterEvaluate ДО
// блока evaluationDependsOn — иначе проект уже оценён и afterEvaluate падает.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        runCatching {
            androidExt.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(androidExt, 36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
