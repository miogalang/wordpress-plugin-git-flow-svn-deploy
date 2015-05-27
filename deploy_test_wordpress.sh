#! /bin/bash
# See https://github.com/GaryJones/wordpress-plugin-git-flow-svn-deploy for instructions and credits.

echo
echo "WordPress Plugin Git SVN Deploy v2.0.0"
echo

## Configuration

# Plugin slug name
PLUGINSLUG='wp-plugin-test'

# Path to temporary svn repo
SVNPATH="./tmp/svn/$PLUGINSLUG"

# URL of SVN repo
SVNURL="https://subversion.assembla.com/svn/$PLUGINSLUG"

# User to use for svn repo
SVNUSER="miog"

# Local directory where to find the git repository
PLUGINDIR="./tmp/git/$PLUGINSLUG"

# Name of the main file of the plugin
MAINFILE="hello.php"

# Git config
# This file should be the base of your git repository
GITPATH="$PLUGINDIR/"
# Plugin git url
GITURL="git@github.com:miogalang/wp-plugin-test.git"

# Let's begin...
echo ".........................................."
echo
echo "Preparing to deploy WordPress plugin"
echo
echo ".........................................."
echo

echo "Making a copy of the git repository"
git clone $GITURL $PLUGINDIR

# Check version in readme.txt is the same as plugin file after translating both to unix line breaks to work around grep's failure to identify mac line breaks
PLUGINVERSION=`grep "Version:" $GITPATH/$MAINFILE | awk -F' ' '{print $NF}' | tr -d '\r'`
echo "$MAINFILE version: $PLUGINVERSION"
READMEVERSION=`grep "^Stable tag:" $GITPATH/readme.txt | awk -F' ' '{print $NF}' | tr -d '\r'`
echo "readme.txt version: $READMEVERSION"

if [ "$READMEVERSION" = "trunk" ]; then
	echo "Version in readme.txt & $MAINFILE don't match, but Stable tag is trunk. Let's proceed..."
elif [ "$PLUGINVERSION" != "$READMEVERSION" ]; then
	echo "Version in readme.txt & $MAINFILE don't match. Exiting...."
	exit 1;
elif [ "$PLUGINVERSION" = "$READMEVERSION" ]; then
	echo "Versions match in readme.txt and $MAINFILE. Let's proceed..."
fi

if git show-ref --tags --quiet --verify -- "refs/tags/$PLUGINVERSION"
	then
		echo "Version $PLUGINVERSION already exists as git tag. Exiting....";
		exit 1;
	else
		echo "Git version does not exist. Let's proceed..."
fi

echo
echo "Creating local copy of SVN repo trunk ..."
svn checkout $SVNURL $SVNPATH --depth immediates
svn update --quiet $SVNPATH/trunk --set-depth infinity

echo "Ignoring GitHub specific files"
svn propset svn:ignore "README.md
.git
.gitignore" "$SVNPATH/trunk/"

echo "Changing to $GITPATH"
cd $GITPATH

echo "Exporting the HEAD of master from git to the trunk of SVN"
git checkout-index -a -f --prefix=$SVNPATH/trunk/

# Support for the /assets folder on the .org repo.
echo "Moving assets"
# Make the directory if it doesn't already exist
mkdir -p $SVNPATH/assets/
mv $SVNPATH/trunk/wordpress-plugin-directory-assets/* $SVNPATH/assets/
svn add --force $SVNPATH/assets/
svn delete --force $SVNPATH/trunk/wordpress-plugin-directory-assets

echo "Changing directory to SVN and committing to trunk"
cd $SVNPATH/trunk/
# Delete all files that should not now be added.
svn status | grep -v "^.[ \t]*\..*" | grep "^\!" | awk '{print $2}' | xargs svn del
# Add all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2}' | xargs svn add
svn commit --username=$SVNUSER -m "Preparing for $PLUGINVERSION release"

echo "Updating WordPress plugin repo assets and committing"
cd $SVNPATH/assets/
# Delete all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^\!" | awk '{print $2}' | xargs svn del
# Add all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2}' | xargs svn add
svn update --accept mine-full $SVNPATH/assets/*
svn commit --username=$SVNUSER -m "Updating assets"

echo "Creating new SVN tag and committing it"
cd $SVNPATH
svn update --quiet $SVNPATH/tags/$PLUGINVERSION
svn copy --quiet trunk/ tags/$PLUGINVERSION/
# Remove assets and trunk directories from tag directory
svn delete --force --quiet $SVNPATH/tags/$PLUGINVERSION/assets
#svn delete --force --quiet $SVNPATH/tags/$PLUGINVERSION/trunk
cd $SVNPATH/tags/$PLUGINVERSION
svn commit --username=$SVNUSER -m "Tagging version $PLUGINVERSION"

echo "Removing temporary directory $SVNPATH"
cd $SVNPATH
cd ..
rm -fr $SVNPATH/

echo "Removing temporary directory $PLUGINDIR"
cd $PLUGINDIR
cd ..
rm -fr $PLUGINDIR/

echo "*** FIN ***"
echo
