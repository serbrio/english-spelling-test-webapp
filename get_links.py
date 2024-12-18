import concurrent.futures
import threading
import scraper

import time


class GetLinks:
	"""
	A class to scrape wiktionary.org in parallel threads
	in order to get links to audio files with pronunciation
	of the given English words.

	Attributes
	----------
	thread_local : instance of class threading.local
		manages thread-local data of the executed threads
	"""

	thread_local = threading.local()


	@classmethod
	def get_link(cls, word):
		"""
		Scrapes wiktionary.org to get a link to audio file
		with pronunciation of an English "word".
    	If link not found, a FileNotFoundError is raised.
		"""
		session = cls.thread_local.session = scraper.Scraper()
		response = session.scrape(word) # raises FileNotFoundError, when gets HTTP 404

		# TODO: get image link

		for data_type in response['pronunciation']:
			for d in data_type['values']:
				if d['type'] in ['audio/wav', 'audio/ogg', 'audio/mpeg']:
					link = "https:" + d['value']
					return link
		# if 'pronunciation' is empty [] or does not contain
		# corresponding values, raise FileNotFoundError
		raise FileNotFoundError


	@classmethod
	def get_links(cls, words):
		"""
		In parallel executes method GetLinks.get_link() for every word in a set of "words".
		Returns a tuple of:
		a dictionary with words as keys and found links as values,
		a list of words, for which links were not found.
		"""
		words = set(words)
		words_links = {}
		notfound_words = []
		# TODO: get image links
		with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
			future_to_url = {executor.submit(cls.get_link, word): word for word in words}
		for future in concurrent.futures.as_completed(future_to_url):
			wrd = future_to_url[future]
			try:
				words_links[wrd] = future.result()
			except FileNotFoundError:
				notfound_words.append(wrd)
		return words_links, notfound_words


def main():
	"""
	Demonstrate how the GetLinks.get_links(words) works for a given list of words:
	print the duration of the execution,
	print the words with the found links (enumerated),
	print the not found words in a separate list.
	"""
	words = ["cat", "dog", "pig", "ant",
			"bumblebee", "horse", "owl",
			"cow", "lion", "monkey",
			"bee", "frog", "spider",
			"notevenaword", "chupakabra", 'biber']

	start_time = time.time()
	words_links, notfound_words = GetLinks.get_links(words)
	duration = time.time() - start_time
	print(f"Duration: {duration}")

	for i, key in enumerate(words_links, start=1):
		print(f"{i}. {key}: {words_links[key]}")

	print(f"Not found {len(notfound_words)} words:", notfound_words)


if __name__ == "__main__":
	main()
