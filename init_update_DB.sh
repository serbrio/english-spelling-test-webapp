#!/bin/bash

# 1) Initializes DB, if given DB-file does not exist.
# If run with "-init" flag, exits here (init only mode).
# 2) Populates DB.
# 3) Downloads audio.


usage() {
cat << EOF
Usage: $0 DB [-init]
    DB .......... path to the DB (web app looks by default for: spelling.db)
    -init ....... enables "initialize only" mode (optional)
EOF
}

# If there are no params, exit
if [ "$#" -lt 1 ]
then
    usage
    exit 1
fi

sqldir="./sql_scripts"
db=$1
initonly=false
shift 1


is_init_only() {
    if [ $initonly == true ]
    then
        echo "Exit (init only)."
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        exit 0
    fi
}


# If there are more than 1 parameter apart from DB, exit
if [ "$#" -gt 1 ]
then
    usage
    exit 1
fi


if [ "${db: -3}" != ".db" ]
# Expression "${file: -3}" used to get last 3 characters,
# see: https://stackoverflow.com/questions/407184/how-to-check-the-extension-of-a-filename-in-a-bash-script
then
    echo "Expected DB file's extension: '.db'. Exiting..."
    exit 1
fi


while (( $# >= 1 )); do
    case $1 in
    -init) initonly=true; break;;
    *) usage ; exit 1;;
    esac;
    shift
done


if [ ! -f "$db" ]
then
    echo
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "+                                                      +"
    echo "+                  Initializing DB...                  +"
    echo "+                                                      +"
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    touch $db
    echo "File '$db' created."
    echo -n "Initializing "
    for sql in $(realpath $sqldir)/*.sql; do
        sqlite3 $db ".read $sql"
        echo -n "."
    done
    echo -e "\nDONE."
    is_init_only
else
    is_init_only
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    read -p "File '$db' exists. Proceed updating DB? yes/no: " confirm
    if [[ ! $confirm =~ ^(YES|Yes|yes|y)$ ]]
    then
        echo "Exit."
        exit 0
    fi
fi

echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+                                                      +"
echo "+                   Populating DB...                   +"
echo "+                                                      +"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
python3.12 ./populateDB.py -db $db
echo -e "\nDB populating FINISHED."

echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+                                                      +"
echo "+                   Getting audio...                   +"
echo "+                                                      +"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
python3.12 ./audio_downloader.py -db $db
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
