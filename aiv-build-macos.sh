#!/usr/bin/env bash
# macOS .pkg build script for AIV application
[ "${DEBUG:-0}" -eq 0 ] || set -x
set -e

export VERSION=${VERSION:-1.0.0}
export RELEASE=${RELEASE:-0}

IDENTIFIER=com.aivhub.aiv
BUILD_DIR=aiv-macos-${VERSION}
ROOT_DIR=${BUILD_DIR}/root

rm -rf "${BUILD_DIR}"
mkdir -p "${ROOT_DIR}/usr/local/bin"
mkdir -p "${ROOT_DIR}/usr/local/lib/aiv/config/drivers"
mkdir -p "${ROOT_DIR}/usr/local/lib/aiv/repository/econfig"
mkdir -p "${ROOT_DIR}/usr/local/lib/aiv/repository/Config"
mkdir -p "${ROOT_DIR}/usr/local/lib/aiv/repository/images"
mkdir -p "${ROOT_DIR}/usr/local/lib/aiv/repository/Default"
mkdir -p "${ROOT_DIR}/usr/local/lib/aiv/universalauth"
mkdir -p "${ROOT_DIR}/Library/LaunchDaemons"

# Copy application files
cp aiv.jar "${ROOT_DIR}/usr/local/lib/aiv/"
cp enviroment "${ROOT_DIR}/usr/local/lib/aiv/"
cp -r config/drivers/* "${ROOT_DIR}/usr/local/lib/aiv/config/drivers/"
cp -r repository/econfig/* "${ROOT_DIR}/usr/local/lib/aiv/repository/econfig/"
cp -r repository/Config/* "${ROOT_DIR}/usr/local/lib/aiv/repository/Config/"
cp -r repository/images/* "${ROOT_DIR}/usr/local/lib/aiv/repository/images/"
cp -r repository/Default/* "${ROOT_DIR}/usr/local/lib/aiv/repository/Default/"

cp macos/bin/aiv "${ROOT_DIR}/usr/local/bin/aiv"
cp macos/bin/aiv_universalauth "${ROOT_DIR}/usr/local/bin/aiv_universalauth"
cp macos/bin/aiv-uninstall.sh "${ROOT_DIR}/usr/local/bin/aiv-uninstall.sh"
chmod 755 "${ROOT_DIR}/usr/local/bin/aiv" "${ROOT_DIR}/usr/local/bin/aiv_universalauth" "${ROOT_DIR}/usr/local/bin/aiv-uninstall.sh"

cp macos/com.aivhub.aiv.plist "${ROOT_DIR}/Library/LaunchDaemons/com.aivhub.aiv.plist"
cp macos/com.aivhub.aiv_universalauth.plist "${ROOT_DIR}/Library/LaunchDaemons/com.aivhub.aiv_universalauth.plist"

# UniversalAuth
cp universalauth.jar "${ROOT_DIR}/usr/local/lib/aiv/"
cp -r universalauth/* "${ROOT_DIR}/usr/local/lib/aiv/universalauth/"
sed -i '' 's,/app/logs,/usr/local/var/log/aiv/universalapp,g' "${ROOT_DIR}/usr/local/lib/aiv/universalauth/application.yml"

# Create default configuration with environment variable substitution
export aiv_base=/usr/local/lib/aiv
export aiv_db_url=jdbc:postgresql://localhost:5432/postgres
export aiv_db_user=postgres
export aiv_db_password=postgres
export security_db_url=jdbc:postgresql://localhost:5432/postgres?currentSchema=security
export security_db_user=postgres
export security_db_password=postgres
export aiv_port=8080

envsubst < repository/econfig/application.yml > "${ROOT_DIR}/usr/local/lib/aiv/repository/econfig/application.yml"
sed -i '' 's,logDir: /var/lib/aiv/logs,logDir: /usr/local/var/log/aiv,g' "${ROOT_DIR}/usr/local/lib/aiv/repository/econfig/application.yml"
sed -i '' 's,/opt/logs,/usr/local/var/log/aiv,g' "${ROOT_DIR}/usr/local/lib/aiv/repository/econfig/logback.xml"

# Build the component package
pkgbuild --root "${ROOT_DIR}" \
  --scripts macos/scripts \
  --identifier "${IDENTIFIER}" \
  --version "${VERSION}" \
  --install-location / \
  "aiv-${VERSION}-${RELEASE}.pkg"

echo "macOS package built successfully:"
ls -la aiv-*.pkg
