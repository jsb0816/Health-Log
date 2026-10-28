plugins {
	// JDK 21 toolchain 자동 다운로드 (로컬에 21이 없어도 빌드 가능)
	id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "fit-api"
