import sqlite3
import re

from contextlib import closing
from flask import redirect, render_template, session
from functools import wraps


def apology(message, code=400):
    """Render message as an apology to user.
    Borrowed from: https://cdn.cs50.net/2024/x/psets/9/finance/helpers.py"""

    def escape(s):
        """
        Escape special characters.

        https://github.com/jacebrowning/memegen#special-characters
        """
        for old, new in [
            ("-", "--"),
            (" ", "-"),
            ("_", "__"),
            ("?", "~q"),
            ("%", "~p"),
            ("#", "~h"),
            ("/", "~s"),
            ('"', "''"),
        ]:
            s = s.replace(old, new)
        return s

    return render_template("apology.html", top=code, bottom=escape(message)), code


def login_required(f):
    """
    Decorate routes to require login.

    https://flask.palletsprojects.com/en/latest/patterns/viewdecorators/
    Borrowed from: https://cdn.cs50.net/2024/x/psets/9/finance/helpers.py
    """

    @wraps(f)
    def decorated_function(*args, **kwargs):
        if session.get("user_id") is None:
            return redirect("/login")
        return f(*args, **kwargs)

    return decorated_function


def dict_factory(cursor, row):
    """
    This is a helper function for the function execute_sql().
    It accepts the cursor and the original row as a tuple
    from sqlite3 connection and returns result as a dictionary.
    """
    fields = [column[0] for column in cursor.description]
    return {key: value for key, value in zip(fields, row)}


def execute_sql(path_to_db, statement, *params):
    """
    Interacts with DB: gets data or makes updates.
    Opens connection to SQLile DB, executes sql statement,
    auto-commits changes and auto-closes connection.

    The 'params' are to bind with placeholders in the statement.

    Returns tuple of data and lastrowid:

    when getting data from DB,
    returns list of dictionaries containing requested data and 0;

    when updating DB,
    returns empty list and 0;

    when inserting data into DB,
    returns empty list and ID of the lastrow.
    """
    with closing(sqlite3.connect(path_to_db)) as con:
        con.row_factory = dict_factory
        try:
            with con:
                cur = con.execute(statement, (*params,))
                return cur.fetchall(), cur.lastrowid
        except sqlite3.Error as err:
            parms = [*params]
            print(f"| x| SQLite: {err}")
            print(f"     {parms}")
            return None, None


def execute_many_sqls(path_to_db, statement, params):
    """
    Opens connection to SQLile DB, executes sql statement,
    auto-commits changes and auto-closes connection.
    Allows updating data in DB: insert, delete, update, replace.
    Params is an iterable of parameters to bind with placeholers in the statement.
    Parameters may be sequence or dict.
    For example params as a tuple of dicts: ({"name": "Bill", "year": 2001},)
    This function utilizes sqlite3.connection.executemany(), thus
    allows using named style in statement like:
    "INSERT INTO table VALUES(:name, :year)".
    """
    with closing(sqlite3.connect(path_to_db)) as con:
        try:
            with con:
                con.executemany(statement, params)
        except sqlite3.Error as err:
            print(f"SQLite Error: {err}")


def generate_hint(word: str, i: int) -> str:
    """
    Return a hint for a **word** - a string containing
    **i** letters of the word beginning with the first one,
    and the stars "*" as placeholders for the remaining letters.

    >>> generate_hint("owl", 1)
    "o**"
    >>> generate_hint("tomato", 3)
    "tom***"
    >>> generate_hint("a cat", 2)
    "a ***"
    """
    if i < 0:
        err = f"i should be integer >= 0, but '{i}' is given"
        raise ValueError(err)
    hint = word[:i] + re.sub(r"\S", "*", word[i:])
    return hint
