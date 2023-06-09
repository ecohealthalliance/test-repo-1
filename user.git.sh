#!/usr/bin/env bash
#
# Script to remove GPG key from git-crypt
#
# It will re-initialize git-crypt for the repository and re-add all keys except
# the one requested for removal.
#
# Note: You still need to change all your secrets to fully protect yourself.
# Removing a user will prevent them from reading future changes but they will
# still have a copy of the data up to the point of their removal.
#
# Use:
#  ./remove-gpg-user.sh [FULL_GPG_FINGERPRINT [FULL_GPG_FINGERPRINT]]
#
# E.g.:
#  ./remove-gpg-user.sh 3BC18383F838C0B815B961480F8CAF5467D ABCD8383F838C0B815B961480F8CAF5467D
#
# The script will create multiple commits to your repo. Feel free to squash them
# all down to one.
#
# Based on https://github.com/AGWA/git-crypt/issues/47#issuecomment-212734882
#
#
set -e

if [ -z "$1" ]
then
    echo " Use:"
    echo "  ./remove-gpg-user.sh [FULL_GPG_FINGERPRINT]"
    echo ""
    echo " E.g.:"
    echo "  ./remove-gpg-user.sh 3BC18383F838C0B815B961480F8CAF5467D"
    exit;
fi

TMPDIR=`mktemp -d`
CURRENT_DIR=`git rev-parse --show-toplevel`
BASENAME=$(basename `pwd`)

# Unlock the directory, we need to copy encrypted versions of the files
git crypt unlock

# Work on copy.
cp -rp `pwd` $TMPDIR


pushd $TMPDIR/$BASENAME

# Remove encrypted files and git-crypt
git crypt status | grep -v "not encrypted" > encrypted-files
awk '{print $2}' encrypted-files | xargs rm
git commit -a -m "Remove encrypted files"
rm -rf .git-crypt
git commit -a -m "Remove git-crypt"
rm -rf .git/git-crypt

# Re-initialize git crypt
git crypt init

# Add existing users, except the
for keyfilename in $CURRENT_DIR/.git-crypt/keys/default/0/*gpg; do
    basename=`basename $keyfilename`
    key=${basename%.*}
    set -x
    if [[ $@ == *$key* ]]; then
        continue;
    fi
    set +x
    git crypt add-gpg-user $key
done

cd $CURRENT_DIR
for i in `awk '{print $2}' ${TMPDIR}/${BASENAME}/encrypted-files`; do
    cp -rp --parents $i $TMPDIR/$BASENAME;
done
cd $TMPDIR/$BASENAME
for i in `awk '{print $2}' encrypted-files`; do
    git add $i
done
git commit -a -m "New encrypted files"
popd

git crypt lock
git pull $TMPDIR/$BASENAME

rm -rf $TMPDIR