# Build and try SuperAwesomeMagicalLinux on a Linux machine with podman (and qemu for `just vm`).
# CI does the same build; see .github/workflows/.

image := "localhost/superawesomemagicallinux"
fedora := "45"
published := "ghcr.io/603madison/superawesomemagicallinux:latest"

# List the recipes
default:
    @just --list

# Build the OS image
build:
    sudo podman build --pull=newer --build-arg FEDORA_VERSION={{fedora}} --tag {{image}}:latest --file Containerfile .

# Run the image's own checks (fonts, desktop pieces, branding)
check:
    sudo podman run --rm {{image}}:latest /usr/libexec/superawesomemagical/check-image

# Open a shell inside the built image to poke around
shell:
    sudo podman run --rm -it {{image}}:latest bash

# Make an installer ISO of the local build in ./output (installed systems then update from GHCR)
iso:
    mkdir -p output
    sed "s|@IMAGE_REF@|{{published}}|g" disk_config/iso.toml > output/config.toml
    just _bib anaconda-iso

# Make a VM disk of the local build with an account to sign in with, in ./output
qcow2 user="me" password="changeme":
    mkdir -p output
    printf '[[customizations.user]]\nname = "%s"\npassword = "%s"\ngroups = ["wheel"]\n' "{{user}}" "{{password}}" > output/config.toml
    just _bib qcow2

_bib type:
    sudo podman run --rm --privileged --pull=newer \
        --security-opt label=type:unconfined_t \
        -v ./output/config.toml:/config.toml:ro \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/bootc-image-builder:latest \
        --type {{type}} --rootfs btrfs --use-librepo=True \
        {{image}}:latest

# Boot the disk from `just qcow2` in a VM (needs KVM)
vm:
    qemu-system-x86_64 -enable-kvm -m 6G -smp 4 -cpu host \
        -device virtio-vga-gl -display gtk,gl=on \
        -drive file=output/qcow2/disk.qcow2,if=virtio \
        -bios /usr/share/OVMF/OVMF_CODE.fd \
        -nic user,model=virtio-net-pci

# Redraw the wallpapers
wallpapers:
    python3 tools/wallpapers.py

# Render the sign-in screen to ./output/sddm.png (and sddm-failed.png) using the built image
signin-preview:
    mkdir -p output
    for state in "" "--failed"; do \
        sudo podman run --rm -v ./tools:/preview:ro,z -v ./output:/out:z \
            -v ./system_files/usr/share/sddm/themes/superawesomemagical:/theme:ro,z \
            -v ./system_files/usr/share/backgrounds/superawesomemagical:/wp:ro,z \
            -e QT_QPA_PLATFORM=offscreen -e QT_FORCE_STDERR_LOGGING=1 \
            {{image}}:latest sh -c "dnf -q -y install qt6-qtdeclarative-devel >/dev/null && \
            /usr/lib64/qt6/bin/qml /preview/signin-preview.qml -- $state"; \
    done
