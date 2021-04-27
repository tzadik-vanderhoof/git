#!/bin/sh

test_description='test git-p4.fallbackEncoding config'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-git-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'add Unicode description' '
	cd "$cli" &&
	echo file1 >file1 &&
	p4 add file1 &&
	p4 submit -d documentación
'

# Unicode descriptions cause clone to throw in some environments. This test
# determines if that is the case in our environment. If so we create a file called "clone_fails".
# We check that file to in subsequent tests to determine what behavior to expect.

clone_fails="$TRASH_DIRECTORY/clone_fails"

test_expect_success 'clone with git-p4.fallbackEncoding unset' '
	test_might_fail git config --global --unset git-p4.fallbackEncoding &&
	test_when_finished cleanup_git && {
		git p4 clone --dest="$git" //depot@all 2>error || (
			cp /dev/null "$clone_fails" &&
			grep "UTF-8 decoding failed. Consider using git config git-p4.fallbackEncoding" error
		)
	}
'

test_expect_success 'clone with git-p4.fallbackEncoding set to "none"' '
	git config --global git-p4.fallbackEncoding none &&
	test_when_finished cleanup_git && {
		(
			test -f "$clone_fails" &&
			test_must_fail git p4 clone --dest="$git" //depot@all 2>error &&
			grep "UTF-8 decoding failed. Consider using git config git-p4.fallbackEncoding" error
		) ||
		(
			! test -f "$clone_fails" &&
			git p4 clone --dest="$git" //depot@all 2>error
		)
	}
'

test_expect_success 'clone with git-p4.fallbackEncoding set to "cp1252"' '
	git config --global git-p4.fallbackEncoding cp1252 &&
	test_when_finished cleanup_git &&
	(
		git p4 clone --dest="$git" //depot@all &&
		cd "$git" &&
		git log --oneline >log &&
		desc=$(head -1 log | cut -d" " -f2) &&
		test "$desc" = "documentación"
	)
'

test_expect_success 'clone with git-p4.fallbackEncoding set to "replace"' '
	git config --global git-p4.fallbackEncoding replace &&
	test_when_finished cleanup_git &&
	(
		git p4 clone --dest="$git" //depot@all &&
		cd "$git" &&
		git log --oneline >log &&
		desc=$(head -1 log | cut -d" " -f2) &&
		{
			(test -f "$clone_fails" &&
				test "$desc" = "documentaci�n"
			) ||
			(! test -f "$clone_fails" &&
				test "$desc" = "documentación"
			)
		}
	)
'

test_expect_success 'unset git-p4.fallbackEncoding' '
	git config --global --unset git-p4.fallbackEncoding
'

test_done
