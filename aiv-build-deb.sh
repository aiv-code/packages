#!/usr/bin/env bash
[ "${DEBUG:-0}" -eq 0 ] || set -x
export VERSION=${VERSION:-1.0.0}
export RELEASE=${RELEASE:-0}

rm -rf aiv-${VERSION}
mkdir aiv-${VERSION}
cd aiv-${VERSION}
mkdir -p config/drivers repository/econfig repository/Config repository/images repository/Default

# Copy necessary files
cp ../aiv.jar ./
cp -r ../config/drivers/* config/drivers/
cp -r ../repository/econfig/* repository/econfig/
cp -r ../repository/Config/* repository/Config/
cp -r ../repository/images/* repository/images/
cp -r ../repository/Default/* repository/Default/

# Create default config
export aiv_base=/var/lib/aiv
export aiv_db_url=jdbc:postgresql://localhost:5432/postgres
export aiv_db_user=postgres
export aiv_db_password=postgres
export security_db_url=jdbc:postgresql://localhost:5432/postgres?currentSchema=security
export security_db_user=postgres
export security_db_password=postgres
export aiv_port=8080
envsubst < ../repository/econfig/application.yml > repository/econfig/application.yml
sed -i 's,logDir: /var/lib/aiv/logs,logDir: /var/log/aiv,g' repository/econfig/application.yml
sed -i 's,/opt/logs,/var/log/aiv,g' repository/econfig/logback.xml

# Create debian folder
mkdir debian
cp -r ../debian/* debian/ -av

# Create changelog file
cat > debian/changelog << EOF
aiv (${VERSION}-${RELEASE}) unstable; urgency=medium

  * Upstream release ${VERSION}
  * Check details at https://aivhub.com

 -- Bot Action <bots@aivhub.com>  $(date -R)

EOF


# Build the package
dpkg-buildpackage -us -uc -b
