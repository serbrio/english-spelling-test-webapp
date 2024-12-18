#!/bin/bash


# TODO: to be fixed after changes in init_update_DB.sh (early: init-DB.sh) and in DB.


###############################################################################
# These tests are meant to test, if TRIGGERS in sqlite DB, which is initiated #
# with init-DB.sh, are set up correctly.                                      #
# This collection of tests represents a scenario,                             #
# thus the order of tests is crucial.                                         #
###############################################################################

db="./test.db"

# Set variables for colors
R='\033[0;31m' # Red
G='\033[0;32m' # Green
C='\033[0;36m' # Cyan
NC='\033[0m' # No Color

test_result_equals_expectation () {
    # Usage: test_result_equals_expectation result expectation tag
    # This function checks, if "result" and "expectation" are the same
    # and prints colored report adding "tag" as comment.

    if [[ $# -ne 3 ]]
        then
            echo -e "${R}FAILED${NC} ("$FUNCNAME" must be provided with 3 arguments; but got: $#)"
            return 1
    fi

    result=$1
    expectation=$2
    tag=$3 # used as tag

    if [[ $result == $expectation ]]
        then
            echo -ne "${G}OK${NC} ($result) "
        else
            echo -ne "${R}FAILED${NC} (Got: $result, expected: $expectation) "
    fi
    echo "($tag)"
}

#################
## Preparation ##
#################

# Clean test.db file, initialize DB.
if [ -f "$db" ]
    then
        echo "++++++++++++++++++++++++++++++++++++++"
        read -p "File '$db' exists. If proceed, it will be owerwritten. Proceed? yes/no: " confirm
        if [[ ! $confirm =~ ^(YES|Yes|yes|y)$ ]]
            then
                echo "Exit."
                exit 0
        fi
        rm -fv $db
fi
bash ../init_update_DB.sh $db

# Populate DB tables: users, blocks, topics
sqlite3 ./test.db "insert into users (username, hash) values ('user-1', 'hash1'), ('user-2', 'hash2')"
sqlite3 ./test.db "insert into blocks (blockname) values ('block-1'), ('block-2')"
sqlite3 ./test.db "insert into topics (topicname, block_id) values ('topic-1', 1), ('topic-2', 1)"

##################################################
## TEST TRIGGER 009-create-trigger-on-words.sql ##
##################################################
echo -e "\n${C}TESTING TRIGGER on WORDS${NC}"
echo -e "\nFIRST INSERT INTO WORDS (WORD-1) TOPIC-1"

sqlite3 ./test.db "insert into words (word, topic_id, link) values('word-1', 1, 'https://word-1.link')"
# Check, words_count updated in topics
result_wc=$(sqlite3 ./test.db -list "select words_count from topics where topicname='topic-1'")
test_result_equals_expectation $result_wc 1 topics_words_count_updated
# Check, max_points updated in topics
result_max_points=$(sqlite3 ./test.db -list "select max_points from topics where topicname='topic-1'")
test_result_equals_expectation $result_max_points 6 topics_max_points_updated

echo -e "\nSECOND INSERT INTO WORDS (WORD-2) TOPIC-1"

sqlite3 ./test.db "insert into words (word, topic_id, link) values('word-2', 1, 'https://word-2.link')"
# Check, words_count updated in topics
result_wc=$(sqlite3 ./test.db -list "select words_count from topics where topicname='topic-1'")
test_result_equals_expectation $result_wc 2 topics_words_count_updated
# Check, max_points updated in topics
result_max_points=$(sqlite3 ./test.db -list "select max_points from topics where topicname='topic-1'")
test_result_equals_expectation $result_max_points 12 topics_max_points_updated

echo -e "\nINSERT INTO WORDS (WORD-3, WORD-4) TOPIC-1"

sqlite3 ./test.db "insert into words (word, topic_id, link) values('word-3', 1, 'https://word-3.link'), ('word-4', 1, 'https://word-4.link')"
# Check, words_count updated in topics
result_wc=$(sqlite3 ./test.db -list "select words_count from topics where topicname='topic-1'")
test_result_equals_expectation $result_wc 4 topics_words_count_updated
# Check, max_points updated in topics
result_max_points=$(sqlite3 ./test.db -list "select max_points from topics where topicname='topic-1'")
test_result_equals_expectation $result_max_points 24 topics_max_points_updated

echo -e "\nINSERT INTO WORDS (WORD-5, WORD-6) TOPIC-2"

sqlite3 ./test.db "insert into words (word, topic_id, link) values('word-5', 2, 'https://word-5.link'), ('word-6', 2, 'https://word-6.link')"
# Check, words_count updated in topics
result_wc=$(sqlite3 ./test.db -list "select words_count from topics where topicname='topic-2'")
test_result_equals_expectation $result_wc 2 topics_words_count_updated
# Check, max_points updated in topics
result_max_points=$(sqlite3 ./test.db -list "select max_points from topics where topicname='topic-2'")
test_result_equals_expectation $result_max_points 12 topics_max_points_updated

###############################################################
## TEST trigger from 010-create-triggers-on-topics-stats.sql ##
###############################################################

echo -e "\n${C}TESTING TRIGGER on TOPICS_STATS: update_words_status_after_topics_stats_insert${NC}"
echo -e "\nINSERT INTO TOPICS_STATS TOPIC-1 USER-1"

# Count all words of topic-1
expected_wc=$(sqlite3 ./test.db -list "select words_count from topics where id=1")

# Insert into topics_stats topic_id=1 with user_id=1
sqlite3 ./test.db "insert into topics_stats (topic_id, user_id) values (1, 1)"

# Check: words from words with topic_id=1 are all present (inserted by trigger)
# in words_stats with user_id=1 (inserted by trigger)
result_wc=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and word_id in (select id from words where topic_id=1)")
test_result_equals_expectation $result_wc $expected_wc words_inserted

# Check: words from words with topic_id=1 are present (inserted by trigger)
# in words_stats with user_id=1 and have status_id=1 (N/A)
result_wc_status=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and status_id=1 and word_id in (select id from words where topic_id=1)")
test_result_equals_expectation $result_wc_status $expected_wc words_status_id_NA

# Check: words from words with topic_id=1 are present (inserted by trigger)
# in words_stats with user_id=1 and have cur_points=0
result_wc_curpts=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and cur_points=0 and word_id in (select id from words where topic_id=1)")
test_result_equals_expectation $result_wc_curpts $expected_wc words_cur_points_0

echo -e "\nINSERT INTO TOPICS_STATS TOPIC-2 USER-1"

# Count all words of topic-2
expected_wc=$(sqlite3 ./test.db -list "select words_count from topics where id=2")

# Insert into topics_stats topic_id=2 with user_id=1
sqlite3 ./test.db "insert into topics_stats (topic_id, user_id) values (2, 1)"

# Check: words from words with topic_id=2 are all present (inserted by trigger)
# in words_stats with user_id=1 (inserted by trigger)
result_wc=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and word_id in (select id from words where topic_id=2)")
test_result_equals_expectation $result_wc $expected_wc words_inserted

# Check: words from words with topic_id=2 are present (inserted by trigger)
# in words_stats with user_id=1 and have status_id=1 (N/A)
result_wc_status=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and status_id=1 and word_id in (select id from words where topic_id=2)")
test_result_equals_expectation $result_wc_status $expected_wc words_status_id_NA

# Check: words from words with topic_id=2 are present (inserted by trigger)
# in words_stats with user_id=1 and have cur_points=0
result_wc_curpts=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and cur_points=0 and word_id in (select id from words where topic_id=2)")
test_result_equals_expectation $result_wc_curpts $expected_wc words_cur_points_0

###############################################################
## TEST triggers from 011-create-trigger-on-words-stats.sql  ##
## TEST trigger from 010-create-triggers-on-topics-stats.sql ##
###############################################################

echo -e "\n${C}################################   SCENARIO 1   #######################################${NC}"
echo -e   "${C}TESTING TRIGGERS on WORDS_STATS: update_topic_cur_points_after_word_status_OK${NC}"
echo -e   "${C}                                 update_topics_status_to_DONE_after_words_status_update${NC}"
echo -e   "${C}TESTING TRIGGER on TOPICS_STATS: update_best_points_after_status_done${NC}"

echo -e "\nUPDATE IN WORDS_STATS WORD-1 (1st OF 4) FOR TOPIC-1 USER-1: STATUS=OK PTS=6"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")

# Update one row (word-1) in words_stats: status_id=2 (OK), cur_points=6 (>0)
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=6 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-1')"
# Get cur_points after update
cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Check: cur_points in topics_stats increased by 6
test_result_equals_expectation $cur_pts_after $((cur_pts_before + 6)) topics_cur_pts_updated

# Count all topics in topics_stats
all_topics=$(sqlite3 ./test.db -list "select count() from topics_stats")
# Count topics with cur_pts=0 in topics_stats
result_topics_cur_pts_0=$(sqlite3 ./test.db -list "select count() from topics_stats where cur_points=0")
# Check cur_points for other topics not changed in topics_stats
test_result_equals_expectation $result_topics_cur_pts_0 $((all_topics - 1)) topics_cur_pts_other_not_changed

# Check status_id=1(STARTED) for topic_id=1, user_id=1
# remains unchanged while not all words of topic updated in words_stats
# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
test_result_equals_expectation $topic_status_after 1 topic_status_1_STARTED_not_changed

###
###
echo -e "\nUPDATE IN WORDS_STATS WORD-2 (2nd OF 4) FOR TOPIC-1 USER-1: STATUS=OK PTS=3"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")

# Update one row (word-2) in words_stats: status_id=2 (OK), cur_points=3 (>0)
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=3 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-2')"
# Get cur_points after update
cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Check: cur_points in topics_stats increased by 3
test_result_equals_expectation $cur_pts_after $((cur_pts_before + 3)) topics_cur_pts_updated

# Count all topics in topics_stats
all_topics=$(sqlite3 ./test.db -list "select count() from topics_stats")
# Count topics with cur_pts=0 in topics_stats
result_topics_cur_pts_0=$(sqlite3 ./test.db -list "select count() from topics_stats where cur_points=0")
# Check cur_points for other topics not changed in topics_stats
test_result_equals_expectation $result_topics_cur_pts_0 $((all_topics - 1)) topics_cur_pts_other_not_changed

# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
# Check status_id=1(STARTED) for topic_id=1, user_id=1
# remains unchanged while not all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 1 topic_status_1_STARTED_not_changed

###
###
echo -e "\nUPDATE IN WORDS_STATS WORD-3 (3rd OF 4) FOR TOPIC-1 USER-1: STATUS=OK PTS=0"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")

# Update one row (word-3) in words_stats: status_id=2 (OK), cur_points=3 (>0)
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=0 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-3')"
# Get cur_points after update
cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Check: cur_points in topics_stats not changed
test_result_equals_expectation $cur_pts_after $cur_pts_before topics_cur_pts_not_changed

# Count all topics in topics_stats
all_topics=$(sqlite3 ./test.db -list "select count() from topics_stats")
# Count topics with cur_pts=0 in topics_stats
result_topics_cur_pts_0=$(sqlite3 ./test.db -list "select count() from topics_stats where cur_points=0")
# Check cur_points for other topics not changed in topics_stats
test_result_equals_expectation $result_topics_cur_pts_0 $((all_topics - 1)) topics_cur_pts_other_not_changed

# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
# Check status_id=1(STARTED) for topic_id=1, user_id=1
# remains unchanged while not all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 1 topic_status_1_STARTED_not_changed

###
###
echo -e "\nUPDATE IN WORDS_STATS WORD-4 (4th OF 4) FOR TOPIC-1 USER-1: STATUS=FAILED"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
t1_cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Get best_points in topics_stats where user_id=1 and topic_id=1 and topic_id=2
t1_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Update one row (word-4) in words_stats: status_id=3 (FAILED), cur_points=0
sqlite3 ./test.db "update words_stats set status_id=3, cur_points=0 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-4')"
# Get cur_points after update
t1_cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Get best_points after update
t1_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Check: cur_points in topics_stats not changed for topic-1
test_result_equals_expectation $t1_cur_pts_after $t1_cur_pts_before topics_cur_pts_not_changed

# Count all topics in topics_stats
all_topics=$(sqlite3 ./test.db -list "select count() from topics_stats")
# Count topics with cur_pts=0 in topics_stats
result_topics_cur_pts_0=$(sqlite3 ./test.db -list "select count() from topics_stats where cur_points=0")
# Check cur_points for other topics not changed in topics_stats
test_result_equals_expectation $result_topics_cur_pts_0 $((all_topics - 1)) topics_cur_pts_other_remain_0

# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
# Check status_id=2(DONE) for topic_id=1, user_id=1
# updated while all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 2 topic_status_2_DONE_updated

# Check: best_points in topics_stats for topic-1 updated
test_result_equals_expectation $t1_best_pts_after $t1_cur_pts_after topics_best_pts_updated
# Check: best_points in topics_stats for topic-2 unchanged
test_result_equals_expectation $t2_best_pts_after $t2_best_pts_before topics_best_pts_other_not_changed

###
###
echo -e "\nUPDATE IN WORDS_STATS WORD-5 (1st OF 2) FOR TOPIC-2 USER-1: STATUS=OK PTS=5"

# Get cur_points in topics_stats where user_id=1 and topic_id=1 and topic_id=2
t1_cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
t2_cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=2")
# Get best_points in topics_stats where user_id=1 and topic_id=1 and topic_id=2
t1_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Update one row (word-5) in words_stats: status_id=2 (OK), cur_points=5, topic_id=2
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=5 where user_id=1 and word_id=(select id from words where topic_id=2 and word='word-5')"
# Get cur_points after update
t1_cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
t2_cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=2")
# Get best_points after update
t1_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Check: cur_points in topics_stats for topic-2 increased by 5
test_result_equals_expectation $t2_cur_pts_after $((t2_cur_pts_before + 5)) topics_cur_pts_updated
# Check: cur_points in topics_stats for topic-1 not changed
test_result_equals_expectation $t1_cur_pts_after $t1_cur_pts_before topics_cur_pts_other_not_changed

# Get actual status_id for user_id=1, topic_id=2 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=2")
# Check status_id=1(STARTED) for topic_id=2, user_id=1
# remains unchanged while not all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 1 topic_status_1_STARTED_not_changed

# Check: best_points in topics_stats unchanged
test_result_equals_expectation $t2_best_pts_after $t2_best_pts_before topics_best_pts_not_changed
# Check: best_points in topics_stats for topic-1 unchanged
test_result_equals_expectation $t1_best_pts_after $t1_best_pts_before topics_best_pts_other_not_changed

###############################################################
## TEST trigger from 010-create-triggers-on-topics-stats.sql ##
###############################################################

echo -e "\n${C}TESTING TRIGGER on TOPICS_STATS: update_words_status_NA_topics_curpts_0_after_topic_status_started${NC}"
echo -e "\nUPDATE TOPICS_STATS FOR TOPIC-1 USER-1: STATUS=1(STARTED)"

# Count all words of topic-1
expected_wc=$(sqlite3 ./test.db -list "select words_count from topics where id=1")

# Update topics_stats status_id=1(STARTED) topic_id=1 with user_id=1
sqlite3 ./test.db "update topics_stats set status_id=1 where user_id=1 and topic_id=1"

# Check: cur_points in topics_stats updated to 0
result_ts_curpts=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
test_result_equals_expectation $result_ts_curpts 0 topics_stats_cur_points_updated_to_0

# Check: words with topic_id=1, user_id=1 are all updated by trigger
# and have status_id=1(N/A)
result_wc_status=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and status_id=1 and word_id in (select id from words where topic_id=1)")
test_result_equals_expectation $result_wc_status $expected_wc words_status_updated_to_NA

# Check: words with topic_id=1, user_id=1 are all updated by trigger
# and have cur_points=0
result_wc_curpts=$(sqlite3 ./test.db -list "select count() from words_stats where user_id=1 and cur_points=0 and word_id in (select id from words where topic_id=1)")
test_result_equals_expectation $result_wc_curpts $expected_wc words_cur_points_updated_to_0


###############################################################
## TEST triggers from 011-create-trigger-on-words-stats.sql  ##
## TEST trigger from 010-create-triggers-on-topics-stats.sql ##
## TEST update of topics best_pts                            ##
###############################################################

echo -e "\n${C}################################   SCENARIO 2   #######################################${NC}"
echo -e   "${C}TESTING TRIGGERS on WORDS_STATS: update_topic_cur_points_after_word_status_OK${NC}"
echo -e   "${C}                                 update_topics_status_to_DONE_after_words_status_update${NC}"
echo -e   "${C}TESTING TRIGGER on TOPICS_STATS: update_best_points_after_status_done${NC}"

echo -e "\nUPDATE IN WORDS_STATS WORD-1 (1st OF 4) FOR TOPIC-1 USER-1: STATUS=OK PTS=5"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")

# Update one row (word-1) in words_stats: status_id=2 (OK), cur_points=6 (>0)
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=5 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-1')"
# Get cur_points after update
cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Check: cur_points in topics_stats increased by 5
test_result_equals_expectation $cur_pts_after $((cur_pts_before + 5)) topics_cur_pts_updated

# Check status_id=1(STARTED) for topic_id=1, user_id=1
# remains unchanged while not all words of topic updated in words_stats
# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
test_result_equals_expectation $topic_status_after 1 topic_status_1_STARTED_not_changed

###
###
echo -e "\nUPDATE in WORDS_STATS WORD-2 (2nd of 4) for TOPIC-1 USER-1: STATUS=OK PTS=5"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")

# Update one row (word-2) in words_stats: status_id=2 (OK), cur_points=5 (>0)
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=5 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-2')"
# Get cur_points after update
cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Check: cur_points in topics_stats increased by 5
test_result_equals_expectation $cur_pts_after $((cur_pts_before + 5)) topics_cur_pts_updated

# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
# Check status_id=1(STARTED) for topic_id=1, user_id=1
# remains unchanged while not all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 1 topic_status_1_STARTED_not_changed

###
###
echo -e "\nUPDATE IN WORDS_STATS WORD-3 (3rd OF 4) FOR TOPIC-1 USER-1: STATUS=OK PTS=5"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")

# Update one row (word-3) in words_stats: status_id=2 (OK), cur_points=5 (>0)
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=5 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-3')"
# Get cur_points after update
cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Check: cur_points in topics_stats not changed
test_result_equals_expectation $cur_pts_after $((cur_pts_before + 5)) topics_cur_pts_updated

# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
# Check status_id=1(STARTED) for topic_id=1, user_id=1
# remains unchanged while not all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 1 topic_status_1_STARTED_not_changed

###
###
echo -e "\nUPDATE IN WORDS_STATS WORD-4 (4th OF 4) FOR TOPIC-1 USER-1: STATUS=FAILED"

# Get cur_points in topics_stats where user_id=1 and topic_id=1
t1_cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Get best_points in topics_stats where user_id=1 and topic_id=1 and topic_id=2
t1_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Update one row (word-4) in words_stats: status_id=3 (FAILED)
sqlite3 ./test.db "update words_stats set status_id=3 where user_id=1 and word_id=(select id from words where topic_id=1 and word='word-4')"
# Get cur_points after update
t1_cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=1")
# Get best_points after update
t1_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Check: cur_points in topics_stats not changed for topic-1
test_result_equals_expectation $t1_cur_pts_after $t1_cur_pts_before topics_cur_pts_not_changed

# Get actual status_id for user_id=1, topic_id=1 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=1")
# Check status_id=2(DONE) for topic_id=1, user_id=1
# updated while all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 2 topic_status_2_DONE_updated

# Check: best_points in topics_stats for topic-1 updated
test_result_equals_expectation $t1_best_pts_after $t1_cur_pts_after topics_best_pts_updated
# Check: best_points in topics_stats for topic-2 unchanged
test_result_equals_expectation $t2_best_pts_after $t2_best_pts_before topics_best_pts_other_not_changed

###
###
echo -e "\nUPDATE IN WORDS_STATS WORD-6 (2nd OF 2) FOR TOPIC-2 USER-1: STATUS=OK PTS=6"

# Get cur_points in topics_stats where user_id=1 and topic_id=2
t2_cur_pts_before=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=2")
# Get best_points in topics_stats where user_id=1 and topic_id=1 and topic_id=2
t1_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_before=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Update one row (word-6) in words_stats: status_id=2 (OK) pts=6
sqlite3 ./test.db "update words_stats set status_id=2, cur_points=6 where user_id=1 and word_id=(select id from words where topic_id=2 and word='word-6')"
# Get cur_points after update
t2_cur_pts_after=$(sqlite3 ./test.db -list "select cur_points from topics_stats where user_id=1 and topic_id=2")
# Get best_points after update
t1_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=1")
t2_best_pts_after=$(sqlite3 ./test.db -list "select best_points from topics_stats where user_id=1 and topic_id=2")

# Check: cur_points in topics_stats increased by 6 for topic-2
test_result_equals_expectation $t2_cur_pts_after $((t2_cur_pts_before + 6)) topics_cur_pts_updated

# Get actual status_id for user_id=1, topic_id=2 in topics_stats
topic_status_after=$(sqlite3 ./test.db -list "select status_id from topics_stats where user_id=1 and topic_id=2")
# Check status_id=2(DONE) for topic_id=1, user_id=1
# updated while all words of topic updated in words_stats
test_result_equals_expectation $topic_status_after 2 topic_status_2_DONE_updated

# Check: best_points in topics_stats for topic-2 updated
test_result_equals_expectation $t2_best_pts_after $t2_cur_pts_after topics_best_pts_updated
# Check: best_points in topics_stats for topic-1 unchanged
test_result_equals_expectation $t1_best_pts_after $t1_best_pts_before topics_best_pts_other_not_changed
