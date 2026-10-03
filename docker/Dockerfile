# World of Words toolchain image (T-0014, decision 0006).
# One image for CI, cloud agents and Codespaces. Every version is pinned here; bump in an infra task.
FROM ubuntu:24.04

ARG GODOT_VERSION=4.7.2
ARG ANDROID_CMDLINE_TOOLS=13114758
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK=28.1.13356709
ARG UV_VERSION=0.12.22
ARG GDTOOLKIT_VERSION=4.5.0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    ANDROID_HOME=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    GRADLE_USER_HOME=/opt/gradle-cache \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    GODOT_VERSION=${GODOT_VERSION}
ENV PATH=${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip git make openjdk-17-jdk-headless \
        python3 python3-venv fontconfig libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Godot headless editor + export templates
RUN base=https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable \
    && curl -fsSL -o /tmp/godot.zip ${base}/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv /tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && curl -fsSL -o /tmp/tpl.tpz ${base}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
    && mkdir -p /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
    && unzip -q /tmp/tpl.tpz -d /tmp/tpl \
    && mv /tmp/tpl/templates/* /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable/ \
    && rm -rf /tmp/godot.zip /tmp/tpl.tpz /tmp/tpl \
    && godot --headless --version

# Android SDK
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL -o /tmp/clt.zip https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip \
    && unzip -q /tmp/clt.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/clt.zip \
    && yes | sdkmanager --licenses >/dev/null \
    && sdkmanager "platform-tools" "platforms;${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" "ndk;${ANDROID_NDK}" >/dev/null

# Python toolchain: uv, then gdtoolkit (gdformat, gdlint) as a uv tool
RUN curl -fsSL https://astral.sh/uv/${UV_VERSION}/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
    && uv tool install gdtoolkit==${GDTOOLKIT_VERSION} \
    && gdformat --version

# Godot editor settings pointing at the SDK (used by Android export)
RUN mkdir -p /root/.config/godot \
    && printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' \
        "${ANDROID_HOME}" "${JAVA_HOME}" > /root/.config/godot/editor_settings-4.7.tres \
    && mkdir -p ${GRADLE_USER_HOME}

WORKDIR /workspace
CMD ["bash"]
