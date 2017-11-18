#!/usr/bin/env bash
TARGET="${HOME}/.dsash/shell"
if [ -d "${TARGET}" ]
then
  echo -n "DSA Shell already exists. Overwrite? (y/n) "
  read RESULT
  if [ "$RESULT" != "y" ]
  then
    exit 1
  fi
  rm -rf "${TARGET}"
fi
mkdir -p "${TARGET}"
git clone git://github.com/IOT-DSA/dslink-dart-shell.git "${TARGET}"
pushd "${TARGET}" > /dev/null
pub get
popd > /dev/null
mkdir -p "${HOME}/bin"
cat > "${HOME}/bin/dsash" <<EOF
#!/usr/bin/env bash
dart $HOME/.dsash/shell/bin/run.dart \$@
exit \$?
EOF
chmod +x "${HOME}/bin/dsash"
echo "Success!"
