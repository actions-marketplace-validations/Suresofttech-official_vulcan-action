# /vulcan/github_cli/create-issue.sh
#!/bin/bash

_write_1st_fl_info() {
	ithFL=$(sh -c "$GITHUB_ACTION_PATH/jq '.[0]' $VULCAN_OUTPUT_DIR/fl_sortby_score.json")
	buggy_source=$(echo $ithFL | $GITHUB_ACTION_PATH/jq -r '.[0]')
	buggy_line=$(echo $ithFL | $GITHUB_ACTION_PATH/jq '.[1]')
	buggy_score=$(echo $ithFL | $GITHUB_ACTION_PATH/jq '.[2]')

    VULCAN_ISSUE_BODY=$( \
        printf "$VULCAN_ISSUE_BODY\n\n----\n%s\n- [ ] %s\n%s/%s#L%d\n%s" \
        "Clicking on the link, you take the page with code highlighted." \
        "Here is most suspicious code piece." \
        $VULCAN_TRIGGER_URL \
        $buggy_source \
        $buggy_line \
        "Recommend debugging here.\nClick below the collapsed section for more FL information." \
    )
}

_open_collapsed_section() {
	VULCAN_ISSUE_BODY=$(printf "$VULCAN_ISSUE_BODY\n\n<details><summary>%s</summary>" "$1")
}

_close_collapsed_section() {
	VULCAN_ISSUE_BODY=$(printf "$VULCAN_ISSUE_BODY\n\n</details>")
}

_write_basic_fl_info() {
	_write_1st_fl_info
	_open_collapsed_section "Click here for more FL"
	for i in {1..4}
	do
		ithFL=$(sh -c "$GITHUB_ACTION_PATH/jq '.[$i]' $VULCAN_OUTPUT_DIR/fl_sortby_score.json")
		buggy_source=$(echo $ithFL | $GITHUB_ACTION_PATH/jq -r '.[0]')
		buggy_line=$(echo $ithFL | $GITHUB_ACTION_PATH/jq '.[1]')
		buggy_score=$(echo $ithFL | $GITHUB_ACTION_PATH/jq '.[2]')
		
		if [ "$buggy_source" = "null" ]; then
			break
		fi
		
		VULCAN_ISSUE_BODY=$( \
			printf "$VULCAN_ISSUE_BODY\n\n----\nSuspicious score: %.2f %s/%s#L%d" \
			$buggy_score \
			$VULCAN_TRIGGER_URL \
			$buggy_source \
			$buggy_line \
		)
	done
	_close_collapsed_section
}

_write_5_more_equal_fl_info() {
	VULCAN_ISSUE_BODY=$( \
		printf "$VULCAN_ISSUE_BODY\n\n----\n%s\n%s\n%s" \
		"Clicking on the link, you take the page with code highlighted." \
		"There are a lot of the suspicious code snippets and show 5 among them." \
		"Recommend that split your tests or adde new tests." \
	)
	
	_open_collapsed_section "Click here for FL information"
	for i in {0..4}
	do
		ithFL=$(sh -c "$GITHUB_ACTION_PATH/jq '.[$i]' $VULCAN_OUTPUT_DIR/fl_sortby_score.json")
		buggy_source=$(echo $ithFL | $GITHUB_ACTION_PATH/jq -r '.[0]')
		buggy_line=$(echo $ithFL | $GITHUB_ACTION_PATH/jq '.[1]')
		buggy_score=$(echo $ithFL | $GITHUB_ACTION_PATH/jq '.[2]')
		
		if [ "$buggy_source" = "null" ]; then
			break
		fi
		
		VULCAN_ISSUE_BODY=$( \
			printf "$VULCAN_ISSUE_BODY\n\n----\nSuspicious score: %.2f %s/%s#L%d" \
			$buggy_score \
			$VULCAN_TRIGGER_URL \
			$buggy_source \
			$buggy_line \
		)
	done
	_close_collapsed_section
}

_write_failed_test_info() {
	FAILED_TEST_COUNT=$($GITHUB_ACTION_PATH/jq '.test.failing | length' $VULCAN_OUTPUT_DIR/info.json)
	VULCAN_ISSUE_BODY=$( \
		printf "$VULCAN_ISSUE_BODY\n\n%s" \
		"There is(are) $FAILED_TEST_COUNT/$((TEST_INDEX-1)) failed test(s)" \
	)
	
	_open_collapsed_section "Click here for the failed test commands"
	FAILED_TEST_COUNT=1
	while read ith_TEST_COMMAND_FILE
	do
		ith_TEST_COMMAND=$(cat $ith_TEST_COMMAND_FILE/test.command)
		VULCAN_ISSUE_BODY=$( \
			printf "$VULCAN_ISSUE_BODY\n\n%s" \
			"$FAILED_TEST_COUNT. [FAILED] {$ith_TEST_COMMAND}" \
		)
		FAILED_TEST_COUNT=$(( $FAILED_TEST_COUNT + 1 ))
	done <<< $($GITHUB_ACTION_PATH/jq -r '.test.failing[]' $VULCAN_OUTPUT_DIR/info.json)
	_close_collapsed_section
}

_write_source_info() {
	_open_collapsed_section "Click here for a list of target sources"
	VULCAN_TRIGGER_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/$GITHUB_SHA"
	while read TARGET_GCOV
	do
		TARGET_SOURCE=${TARGET_GCOV/.gcov/}
		VULCAN_ISSUE_BODY=$( \
			printf "$VULCAN_ISSUE_BODY\n\n%s" \
			"[$TARGET_SOURCE]($VULCAN_TRIGGER_URL/$TARGET_SOURCE)" \
		)
	done <<< $($GITHUB_ACTION_PATH/jq -r '.sources[]' $VULCAN_OUTPUT_DIR/info.json)
	_close_collapsed_section
}

_write_coverage_info() {
	COVERAGE_INFO=$($GITHUB_ACTION_PATH/jq -r '.coverage' $VULCAN_OUTPUT_DIR/info.json)
	VULCAN_ISSUE_BODY=$( \
		printf "$VULCAN_ISSUE_BODY\n%s %.2f percent" \
		"Coverage:" \
		"$COVERAGE_INFO" \
	)
}

_write_info() {
	_write_coverage_info
	_write_source_info
	_write_failed_test_info
}

_write_fl_info() {
	VULCAN_TRIGGER_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/$GITHUB_SHA"
	$GITHUB_ACTION_PATH/jq 'sort_by(.[2]) | reverse' $VULCAN_OUTPUT_DIR/fl.json > $VULCAN_OUTPUT_DIR/fl_sortby_score.json
	$GITHUB_ACTION_PATH/jq '.[:5]' $VULCAN_OUTPUT_DIR/fl_sortby_score.json > $VULCAN_OUTPUT_DIR/fl_top5.json
	
	is_more_than_top5=$($GITHUB_ACTION_PATH/jq 'group_by(.[2])' $VULCAN_OUTPUT_DIR/fl_top5.json | $GITHUB_ACTION_PATH/jq '.[1]')
	
	if [ "$is_more_than_top5" = "null" ];
	then
		_write_5_more_equal_fl_info
	else
		VULCAN_ISSUE_BODY=$( \
			printf "$VULCAN_ISSUE_BODY\n\n----" \
		)
		_open_collapsed_section "Click here for FL information"
		_write_basic_fl_info
		_close_collapsed_section
	fi
}

_write_patch_info() {
	VULCAN_ISSUE_BODY=$( \
		printf "$VULCAN_ISSUE_BODY\n\n----\n%d patch(es) generated by vulcan\n" \
		$VULCAN_PLAUSIBLE_COUNT \
	)
	if [ ! 0 -eq $VULCAN_PLAUSIBLE_COUNT ]; then
		_open_collapsed_section "plausible patches info"
		PLAUSIBLE_PATCH_INFO=$($GITHUB_ACTION_PATH/jq '.' $MSV_PLAUSIBLE_JSON)
		VULCAN_ISSUE_BODY=$(
			printf "$VULCAN_ISSUE_BODY\n\n%s" \
			"$PLAUSIBLE_PATCH_INFO" \
		)
		_close_collapsed_section
		
		_open_collapsed_section "plausible patch diff info"
		CODE_BLOCK="\x60\x60\x60"
		for diff_file in $(sh -c "ls $PATCH_OUTPUT_PATH/*.diff")
		do
			VULCAN_ISSUE_BODY=$( \
				printf "$VULCAN_ISSUE_BODY\n\n----\n$CODE_BLOCK c\n$(cat $diff_file)\n$CODE_BLOCK"
			)
		done
		_close_collapsed_section
	fi
}

_generate_issue_contents() {
	VULCAN_TITLE="Vulcan"
	VULCAN_ISSUE_BODY="This issue is generated by Vulcan for commit: $GITHUB_SHA"
	_write_info
	_write_fl_info
	if [ ! 0 -eq $VULCAN_PLAUSIBLE_COUNT ];
	then
		_write_patch_info
	fi
}

_create_issue() {
	echo ==========Creating Issue==========
	VULCAN_ISSUE_CREATE_RESULT=$(\
		gh issue create \
		-t "$VULCAN_TITLE" \
		-a "$GITHUB_ACTOR" \
		-b "$VULCAN_ISSUE_BODY" \
	)
	printf "$VULCAN_ISSUE_CREATE_RESULT\n"
	echo ==================================
}

_generate_issue_contents
_create_issue
