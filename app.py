from flask import Flask, redirect, render_template, request, session, send_from_directory
from flask_session import Session
from werkzeug.security import check_password_hash, generate_password_hash

from helpers import apology, login_required, execute_sql, generate_hint


AUDIO_FOLDER = "src/audio/"
IMAGES_FOLDER = "src/images/"

# Configure application
app = Flask(__name__)

# Configure session to use filesystem (instead of signed cookies)
app.config["SESSION_PERMANENT"] = False
app.config["SESSION_TYPE"] = "filesystem"
app.config["AUDIO_FOLDER"] = AUDIO_FOLDER
app.config["IMAGES_FOLDER"] = IMAGES_FOLDER
Session(app)


db = "spelling.db"


@app.after_request
def after_request(response):
    """Ensure responses aren't cached"""
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Expires"] = 0
    response.headers["Pragma"] = "no-cache"
    return response


@app.route("/", defaults={"highlighted": None})
@app.route("/highlighted/<string:highlighted>")
@login_required
def index(highlighted):
    """Show portfolio of user"""
    # Highlighted is id of topic, which is to be highlighted. Default: None.
    # Get list of all topics with the status (if applicable) for the current user.
    topics, _ = execute_sql(
        db,
        "SELECT t.id, t.topicname, t.block_id, t.blockname, t.max_points, t.words_count, "
        "ts.status_id, ts.best_points, ts.cur_points "
        "FROM (topics JOIN blocks ON blocks.id=topics.block_id) AS t "
        "LEFT JOIN "
        "(SELECT * FROM topics_stats WHERE user_id=?) as ts "
        "ON t.id=ts.topic_id "
        "ORDER BY block_id, t.id",
        session["user_id"]
    )

    # Group topics by blockname
    grouped = {}
    for topic in topics:
        if topic["blockname"] not in grouped:
            grouped[topic["blockname"]] = [topic]
        else:
            grouped[topic["blockname"]].append(topic)

    return render_template("portfolio.html", grouped=grouped, highlighted=highlighted)


@app.route("/login", methods=["GET", "POST"])
def login():
    """Log user in"""
    # Forget any user_id
    session.clear()

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":
        # Ensure username was submitted
        if not request.form.get("username"):
            return apology("must provide username", 403)

        # Ensure password was submitted
        elif not request.form.get("password"):
            return apology("must provide password", 403)

        # Query database for username
        rows, _ = execute_sql(
            db,
            "SELECT * FROM users WHERE username = ?",
            request.form.get("username")
            )

        # Ensure username exists and password is correct
        if len(rows) != 1 or not check_password_hash(
            rows[0]["hash"], request.form.get("password")
            ):
            return apology("invalid username and/or password", 403)

        # Remember which user has logged in
        session["user_id"] = rows[0]["id"] # used in many places
        session["username"] = rows[0]["username"] # used in layout.html

        # Redirect user to home page
        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("login.html")


@app.route("/logout")
def logout():
    """Log user out"""

    # Forget any user_id
    session.clear()

    # Redirect user to login form
    return redirect("/")


@app.route("/register", methods=["GET", "POST"])
def register():
    """Register user"""

    # Forget any user_id
    session.clear()

    if request.method == "POST":

        username = request.form.get("username")

        # Ensure username was submitted
        if not username:
            return apology("must provide username", 400)

        rows, _ = execute_sql(db, "SELECT * FROM users WHERE username=?", username)

        # Ensure username does not exist already
        if rows:
            return apology("username exists", 400)

        password = request.form.get("password")
        confirmation = request.form.get("confirmation")

        # Ensure password was submitted
        if not password:
            return apology("must provide password", 400)

        # Ensure password confirmation was submitted
        elif not confirmation:
            return apology("must confirm password", 400)

        elif password != confirmation:
            return apology("passwords do not match", 400)

        hash = generate_password_hash(password)
        execute_sql(db, "INSERT INTO users (username, hash) VALUES(?, ?)", username, hash)
        return redirect("/login")
        # TODO: auto login after registration
    else:
        return render_template("register.html")


@app.route("/changepwd", methods=["GET", "POST"])
@login_required
def changepwd():
    """Change password."""
    # Get username of the current user from DB
    rows, _ = execute_sql(db, "SELECT username FROM users WHERE id=?",
                           session["user_id"])
    username = rows[0]["username"]

    if request.method == "POST":
        password = request.form.get("password")
        new_password = request.form.get("new_password")
        confirmation = request.form.get("confirmation")

        # Ensure password was submitted
        if not password:
            return apology("must provide current password", 403)

        # Ensure new password was submitted
        elif not new_password:
            return apology("must provide new password", 403)

        # Ensure password confirmation was submitted
        elif not confirmation:
            return apology("must confirm new password", 403)

        # Ensure correct current password provided
        rows, _ = execute_sql(db, "SELECT hash FROM users WHERE id=?",
                                  session["user_id"])
        hash_current = rows[0]["hash"]
        if not check_password_hash(hash_current, password):
            return apology("wrong current password")

        # Ensure new password and confirmation match
        elif new_password != confirmation:
            return apology("new passwords do not match", 403)

        hash_new_password = generate_password_hash(new_password)
        execute_sql(db, "UPDATE users SET hash=? WHERE id=?", hash_new_password, session["user_id"])

        return redirect("/")
    else:
        return render_template("changepwd.html", username=username)


@app.route("/spelling", methods=["GET", "POST"])
@login_required
def spelling():
    """Spell word"""

    # TODO: IMAGES:
    #       Implement in GetLinks functionality to get links for images.
    # TODO: SAVE IMAGES ON SERVER like AUDIO,
    #       name files according to DB ids, save in 'src/images'.

    # TODO: ON CLIENT SIDE:
    #       - count available hints,
    #       - disable button "Give hint", if hints == len(word).

    if request.method == "POST":
        topic_id = request.form.get("topic_id")
        topicname = request.form.get("topicname")
        blockname = request.form.get("blockname")
        redo = request.form.get("redo")

        # If no topic_id provided, redirect to "/"
        if not topic_id:
            return redirect("/")

        # Get topic_status for (topic_id user_id)
        ts_rows, _ = execute_sql(
            db,
            "SELECT status_id FROM topics_stats "
            "WHERE topic_id=? "
            "AND user_id=?",
            topic_id, session["user_id"]
        )

        if not ts_rows:
            # If topic (topic_id, user_id) not in topics_stats, insert it
            execute_sql(
                db,
                "INSERT INTO topics_stats "
                "(topic_id, user_id) "
                "VALUES (?, ?)",
                topic_id, session["user_id"]
            )
            # Default topic_status = 1(STARTED)
        else:
            topic_status = ts_rows[0]["status_id"]

            # If topic_status == 2(DONE) and redo==True,
            # set topic_status to 1(STARTED),
            # else assume topic is DONE, render congratulation.
            if topic_status == 2:
                if redo:
                    execute_sql(
                        db,
                        "UPDATE topics_stats "
                        "SET status_id=1 "
                        "WHERE topic_id=? "
                        "AND user_id=?",
                        topic_id, session["user_id"]
                    )
                else:
                    # TODO: add some sparkles/fireworks
                    return redirect(f"/highlighted/{topic_id}")

        # Get a random not yet spelled word for:
        # user_id, topic_id, status_id==1(N/A)
        w_rows, _ = execute_sql(
            db,
            "SELECT word_id, cur_points "
            "FROM words_stats "
            "WHERE topic_id=? "
            "AND user_id=? "
            "AND status_id=1 "
            "ORDER BY RANDOM() "
            "LIMIT 1",
            topic_id, session["user_id"]
            )

        if not w_rows:
            # If no words left with status_id=1(N/A),
            # topic's status is set to 2(DONE)
            # by trigger "update_topics_status_to_done_after_words_status_update".

            # TODO: -> redirect to Congratulations!
            # TODO: what to do if there are no words in topic

            return apology(f"No words in: '{topicname}'!")

        else:
            word = w_rows[0] # {word_id: value , cur_points: value}
            word_id = word["word_id"]

            # While word's status == 1(N/A) and topic status == STARTED,
            # let user respell word unlimited number of times
            # (crucial for the case when user got some hints,
            # but has not submitted word).
            if word["cur_points"] != 0:
                execute_sql(
                    db,
                    "UPDATE words_stats "
                    "SET cur_points=0 "
                    "WHERE word_id=? "
                    "AND topic_id=? "
                    "AND user_id=?",
                    word_id, topic_id, session["user_id"]
                )

            return render_template("spell_word.html", word_id=word_id,
                                   topic_id=topic_id, topicname=topicname, blockname=blockname)
    else:
        return redirect("/")


@app.route("/hint")
@login_required
def hint():
    """Give hint for a word."""
    word_id = request.args.get("word_id", None)
    topic_id = request.args.get("topic_id", None)

    if not word_id or not topic_id:
        return apology("Bad hint request", 400)

    # Get word, cur_points from DB
    w_rows, _ = execute_sql(
        db,
        "SELECT word, cur_points "
        "FROM words "
        "JOIN words_stats ON id=word_id "
        "WHERE id=? "
        "AND topic_id=? "
        "AND user_id=?",
        word_id, topic_id, session["user_id"]
    )

    if not w_rows:
        return apology("Bad hint request", 400)

    w_row = w_rows[0]
    # If this is the last hint:
    # return whole word, update cur_points for word in DB.
    if abs(w_row["cur_points"] - 1) == len(w_row["word"]):
        execute_sql(
            db,
            "UPDATE words_stats "
            "SET cur_points = cur_points - 1 "
            "WHERE word_id=? "
            "AND topic_id=? "
            "AND user_id=?",
            word_id, topic_id, session["user_id"]
        )
        return w_row["word"]
    # If amount of hints exceeded the word length,
    # return whole word.
    elif abs(w_row["cur_points"] - 1) > len(w_row["word"]):
        return w_row["word"]
    else:
        # Update cur_points for word in DB
        execute_sql(
            db,
            "UPDATE words_stats "
            "SET cur_points = cur_points - 1 "
            "WHERE word_id=? "
            "AND topic_id=? "
            "AND user_id=?",
            word_id, topic_id, session["user_id"]
        )
        # Generate and return hint
        number = abs(w_row["cur_points"] - 1)
        hint = generate_hint(w_row["word"], number)
        return hint


@app.route("/spelled", methods=["POST"])
@login_required
def spelled():
    spelling_result = request.form.get("spelling_result")
    if spelling_result:
        spelling_result = spelling_result.strip()

    topic_id = request.form.get("topic_id")
    topicname = request.form.get("topicname")
    blockname = request.form.get("blockname")
    word_id = request.form.get("word_id")

    if not topic_id or not topicname or not blockname or not word_id:
        return apology("Missing data", 400)

    # Get word from DB by word_id
    w_rows, _ = execute_sql(db, "SELECT word FROM words WHERE id=?", word_id)

    if not w_rows:
        message = "Word does not exist"
        return render_template("word-not-exist.html", topic_id=topic_id,
                               topicname=topicname, blockname=blockname)

    word = w_rows[0]["word"]
    if spelling_result == word:
        # Set word status = OK in words_stats
        execute_sql(
            db,
            "UPDATE words_stats "
            "SET status_id=2, cur_points=? + cur_points "
            "WHERE word_id=? "
            "AND topic_id=? "
            "AND user_id=?",
            len(word), word_id, topic_id, session["user_id"]
        )
        # Info:
        # if all words in topic have status_id != 1(N/A) i.e. 2 or 3 (OK or FAILED),
        # topic's status_id is set to DONE
        # by trigger "update_topics_status_to_done_after_words_status_update".

        # TODO: implement rotation of congrats (on client side).
        # See: https://stackoverflow.com/questions/4550505/getting-a-random-value-from-a-javascript-array

        return render_template("word-correct.html", word=word, topic_id=topic_id,
                               topicname=topicname, blockname=blockname)
    else:
        # Set word's status = FAILED
        execute_sql(
            db,
            "UPDATE words_stats "
            "SET status_id=3 "
            "WHERE word_id=? "
            "AND topic_id=? "
            "AND user_id=?",
            word_id, topic_id, session["user_id"]
        )
        # Info:
        # if all words in topic have status_id != 1(N/A) i.e. 2 or 3 (OK or FAILED),
        # topic's status_id is set to DONE
        # by trigger "update_topics_status_to_done_after_words_status_update".

        # TODO: implement rotation of error messages (on client side)

    return render_template("word-wrong.html", word=word,
                           spelling_result=spelling_result,topic_id=topic_id,
                           topicname=topicname, blockname=blockname)


@app.route("/audio/<string:name>", methods=["GET"])
@login_required
def return_audio(name):
    return send_from_directory(
        app.config["AUDIO_FOLDER"], name, as_attachment=False
    )


@app.route("/images/<string:name>", methods=["GET"])
@login_required
def return_image(name):
    return send_from_directory(
        app.config["IMAGES_FOLDER"], name, as_attachment=False
    )

