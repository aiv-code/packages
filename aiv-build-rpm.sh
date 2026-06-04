#!/usr/bin/env bash
# RPM package build script for AIV application
[ "${DEBUG:-0}" -eq 0 ] || set -x

export VERSION=${VERSION:-1.0.0}
export RELEASE=${RELEASE:-0}

# Clean up any existing build directories
rm -rf ~/rpmbuild
rm -rf aiv-${VERSION}

# Create RPM build directory structure
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create source directory
mkdir -p aiv-${VERSION}
cd aiv-${VERSION}

# Create application directory structure
mkdir -p usr/bin
mkdir -p var/lib/aiv/{config/drivers,repository/{econfig,Config,images,Default}}
mkdir -p var/log/aiv
mkdir -p etc/systemd/system

# Copy necessary application files
cp ../debian/bin/aiv usr/bin/
cp ../aiv.jar var/lib/aiv/
cp -r ../config/drivers/* var/lib/aiv/config/drivers/
cp -r ../repository/econfig/* var/lib/aiv/repository/econfig/
cp -r ../repository/Config/* var/lib/aiv/repository/Config/
cp -r ../repository/images/* var/lib/aiv/repository/images/
cp -r ../repository/Default/* var/lib/aiv/repository/Default/

# Create default configuration with environment variable substitution
export aiv_base=/var/lib/aiv
export aiv_db_url=jdbc:postgresql://localhost:5432/postgres
export aiv_db_user=postgres
export aiv_db_password=postgres
export security_db_url=jdbc:postgresql://localhost:5432/postgres?currentSchema=security
export security_db_user=postgres
export security_db_password=postgres
export aiv_port=8080

# Apply configuration templates
envsubst < ../repository/econfig/application.yml > var/lib/aiv/repository/econfig/application.yml
sed -i 's,logDir: /var/lib/aiv/logs,logDir: /var/log/aiv,g' var/lib/aiv/repository/econfig/application.yml
sed -i 's,/opt/logs,/var/log/aiv,g' var/lib/aiv/repository/econfig/logback.xml

# Create systemd service file
cat > etc/systemd/system/aiv.service << 'EOF'
[Unit]
Description=AIV Application Service
After=network.target

[Service]
Type=simple
User=aiv
Group=aiv
ExecStart=/usr/bin/aiv
WorkingDirectory=/var/lib/aiv
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

# Environment variables
Environment=JAVA_OPTS="-Xmx2g -Xms512m"

[Install]
WantedBy=multi-user.target
EOF

# Create the source tarball
cd ..
tar czf ~/rpmbuild/SOURCES/aiv-${VERSION}.tar.gz aiv-${VERSION}

# Generate RPM spec file
cat > ~/rpmbuild/SPECS/aiv.spec << EOF
Name:           aiv
Version:        ${VERSION}
Release:        ${RELEASE}%{?dist}
Summary:        AIV Application Package
License:        Proprietary
URL:            aivhub.com
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd

%description
AIV is a comprehensive application for data processing and analysis.
This package contains the AIV application server and related components.

%prep
%setup -q

%build
# No build step needed for Java application

%install
rm -rf %{buildroot}

# Create directory structure
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/var/lib/aiv
mkdir -p %{buildroot}/var/log/aiv
mkdir -p %{buildroot}/etc/systemd/system

# Copy application files
cp usr/bin/aiv %{buildroot}/usr/bin/
cp -r var/lib/aiv/* %{buildroot}/var/lib/aiv/
cp etc/systemd/system/aiv.service %{buildroot}/etc/systemd/system/

%files
%defattr(-,root,root,-)
/usr/bin/aiv
/var/lib/aiv/
/etc/systemd/system/aiv.service
%attr(755,aiv,aiv) /var/lib/aiv
%attr(755,aiv,aiv) /var/log/aiv

%config(noreplace) /var/lib/aiv/repository/*

%pre
# Create aiv user and group if they don't exist
getent group aiv >/dev/null || groupadd -r aiv
getent passwd aiv >/dev/null || useradd -r -g aiv -d /var/lib/aiv -s /bin/false aiv

# Stop AIV service before upgrade
if [ \$1 -gt 1 ]; then
    # This is an upgrade
    systemctl stop aiv.service 2>/dev/null || true
fi

%post
# Reload systemd and enable service
systemctl daemon-reload
systemctl enable aiv.service

# Set proper ownership
chown -R aiv:aiv /var/lib/aiv
chown -R aiv:aiv /var/log/aiv

# Start AIV service after installation/upgrade
if [ \$1 -eq 1 ]; then
    # Fresh installation
    echo "AIV installed successfully. Start service with: systemctl start aiv.service"
elif [ \$1 -gt 1 ]; then
    # Upgrade - restart the service
    systemctl start aiv.service
    echo "AIV upgraded successfully and service restarted"
fi

%preun
# Stop and disable service before removal
if [ \$1 -eq 0 ]; then
    systemctl stop aiv.service
    systemctl disable aiv.service
fi

%postun
# Reload systemd after removal
systemctl daemon-reload

# Remove user and group if package is completely removed
if [ \$1 -eq 0 ]; then
    userdel aiv 2>/dev/null || true
    groupdel aiv 2>/dev/null || true
fi

%clean
rm -rf %{buildroot}

%changelog
* $(date +'%a %b %d %Y') GitHub Actions <github-actions@users.noreply.github.com> - ${RELEASE}
- Automated build from GitHub Actions

EOF

# Build the RPM package
rpmbuild -ba ~/rpmbuild/SPECS/aiv.spec

# Copy the built RPM to current directory
cp ~/rpmbuild/RPMS/noarch/aiv-${VERSION}*.rpm ./

echo "RPM package built successfully:"
ls -la *.rpm
