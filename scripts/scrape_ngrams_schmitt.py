import requests
import re
import pandas as pd
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_OUTPUT = ROOT / "data" / "raw" / "ngram_raw_schmitt.csv"

def get_ngram_data(queries, year_start=1945, year_end=2019, corpus=26, smoothing=0):
    """
    Fetch Google Ngram data for a list of search terms.
    
    queries: list of strings, e.g. ["Carl Schmitt", "Walter Benjamin"]
    corpus: 26 = English (2019)
    """
    
    results = {}
    
    for i, query in enumerate(queries):
        # Format URL
        url = (
            f"https://books.google.com/ngrams/graph"
            f"?content={query.replace(' ', '+')}"
            f"&year_start={year_start}"
            f"&year_end={year_end}"
            f"&corpus={corpus}"
            f"&smoothing={smoothing}"
        )

        headers = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        }

        response = requests.get(url, headers=headers)

        if response.status_code != 200:
            print(f"Failed to fetch {query}: status {response.status_code}")
            results[query] = None
            continue

        # Extract the timeseries array from the HTML
        pattern = r'"timeseries":\s*\[([^\]]+)\]'
        match = re.search(pattern, response.text)

        if not match:
            print(f"No timeseries found for {query}")
            results[query] = None
            continue

        # Parse the floating point numbers
        raw = match.group(1)
        values = [float(x.strip()) for x in raw.split(',')]

        # Build a year index
        years = list(range(year_start, year_end + 1))

        # Sanity check
        if len(values) != len(years):
            print(f"Warning: {query} returned {len(values)} values for {len(years)} years")

        results[query] = dict(zip(years, values))
        print(f"Fetched {query}: {len(values)} years of data")

        # Rate limit
        if (i + 1) % 10 == 0 and (i + 1) % 50 != 0:
            time.sleep(10)
        elif (i + 1) % 50 == 0:
            time.sleep(60)
        else:
            time.sleep(2)
    
    return results


def to_dataframe(results):
    """Convert results dict to a tidy DataFrame."""
    df = pd.DataFrame(results)
    df.index.name = "year"
    return df


if __name__ == "__main__":
    
    # Donor pool — adjust as needed
    authors = [
    "Abraham Lincoln",
    "Adam Smith",
    "Aeschylus",
    "Aesop",
    "Alessandro Manzoni",
    "Alexander Hamilton",
    "Alexander Pope",
    "Amadeus Wendt",
    "Ambroise Paré",
    "Aquinas",
    "Archibald Geikie",
    "Aristophanes",
    "Aristotle",
    "Arthur Moeller van den Bruck",
    "Auberon Herbert",
    "August Bebel",
    "Auguste Comte",
    "Augustine",
    "Bakunin",
    "Barthold Georg Niebuhr",
    "Bastiat",
    "Benjamin Constant",
    "Benjamin Franklin",
    "Bentham",
    "Bernard Bolzano",
    "Bigges",
    "Blanqui",
    "Bruno Hildebrand",
    "Carl Friedrich",
    "Carl Schmitt",
    "Carl Stumpf",
    "Cellini",
    "Cervantes",
    "Charles Darwin",
    "Charles Fourier",
    "Chaucer",
    "Christian Schreiber",
    "Christian Wilhelm von Dohm",
    "Cicero",
    "Clausewitz",
    "Copernicus",
    "Dante Alighieri",
    "David Ricardo",
    "de Gouges",
    "Descartes",
    "Dietrich Tiedemann",
    "Dilthey",
    "Dostoyevsky",
    "Dryden",
    "Durkheim",
    "E T A Hoffmann",
    "Ebbinghaus",
    "Edgar Jung",
    "Edmund Burke",
    "Edmund Spenser",
    "Eduard Beneke",
    "Eduard Bernstein",
    "Eduard von Hartmann",
    "Eduard Zeller",
    "Edward Bellamy",
    "Edward Haies",
    "Edward Jenner",
    "Epictetus",
    "Ernst Cassirer",
    "Ernst Jünger",
    "Euripides",
    "Faraday",
    "Ferdinand Lassalle",
    "Ferdinand Tönnies",
    "Francis Bacon",
    "Francis Pretty",
    "Franz Brentano",
    "Frederick Douglass",
    "Frege",
    "Friedrich Ast",
    "Friedrich Carl von Savigny",
    "Friedrich Heinrich Jacobi",
    "Friedrich Krause",
    "Friedrich List",
    "Friedrich Schiller",
    "Friedrich Schlegel",
    "Fritz Schultze",
    "Froissart",
    "Gaetano Mosca",
    "Goethe",
    "Gotthold Ephraim Lessing",
    "Gottlob Ernst Schulze",
    "Grimmelshausen",
    "Gustav Freytag",
    "Gustav Schönberg",
    "Hölderlin",
    "Hamann",
    "Hans Christian Andersen",
    "Hans Kelsen",
    "Heinrich Feder",
    "Heinrich Rickert",
    "Helmholtz",
    "Henry Fielding",
    "Henry George",
    "Herbart",
    "Herbert Spencer",
    "Herder",
    "Hermann Cohen",
    "Hermann Lotze",
    "Herodotus",
    "Hippocrates",
    "Hippolyte Taine",
    "Hobbes",
    "Homer",
    "Hume",
    "Isaiah Berlin",
    "Izaak Walton",
    "James Fitzjames Stephen",
    "James Madison",
    "Jean Racine",
    "John Bunyan",
    "John C Calhoun",
    "John Calvin",
    "John Knox",
    "John Locke",
    "John Milton",
    "John Rawls",
    "John Ruskin",
    "John Stuart Mill",
    "John Woolman",
    "Jonathan Swift",
    "Joseph Lister",
    "Julius Evola",
    "Külpe",
    "Kafka",
    "Karl Jaspers",
    "Karl Knies",
    "Karl Mannheim",
    "Kelvin",
    "Kempis",
    "Kropotkin",
    "Kuno Fischer",
    "Laspeyres",
    "Leibniz",
    "Leo Strauss",
    "Lord Acton",
    "Lord Byron",
    "Ludwig Büchner",
    "Lujo Brentano",
    "Machiavelli",
    "Mainländer",
    "Malory",
    "Malthus",
    "Marcus Aurelius",
    "Marlowe",
    "Martin Luther",
    "Max Weber",
    "Mazzini",
    "Molière",
    "Montaigne",
    "Montesquieu",
    "Moses Mendelssohn",
    "Nassau Senior",
    "Natorp",
    "Newton",
    "Norbert Elias",
    "Oliver Goldsmith",
    "Oliver Wendell Holmes",
    "Oscar Wilde",
    "Oswald Spengler",
    "Otto Liebmann",
    "Otto Pfleiderer",
    "Pasteur",
    "Pedro Calderón de la Barca",
    "Percy Bysshe Shelley",
    "Pericles",
    "Philip Nichols",
    "Pierre Corneille",
    "Plato",
    "Pliny the Younger",
    "Plutarch",
    "Proudhon",
    "Quentin Skinner",
    "Ralph Waldo Emerson",
    "Ranke",
    "Raymond Aron",
    "Renan",
    "Richard Cobden",
    "Rilke",
    "Robert Browning",
    "Robert Burns",
    "Robert Merton",
    "Robert Nozick",
    "Robert Owen",
    "Rodbertus",
    "Rousseau",
    "Rudolf Haym",
    "Sainte Beuve",
    "Samuel Johnson",
    "Schäffle",
    "Scheler",
    "Schleiermacher",
    "Schmoller",
    "Sigismund Beck",
    "Simmel",
    "Simon Newcomb",
    "Sismondi",
    "Sombart",
    "Sophocles",
    "Spinoza",
    "Tacitus",
    "Talcott Parsons",
    "Thünen",
    "Theodor Fontane",
    "Theodor Lipps",
    "Thomas Abbt",
    "Thomas Browne",
    "Thomas Carlyle",
    "Thomas Jefferson",
    "Thomas Mann",
    "Thomas More",
    "Thoreau",
    "Thucydides",
    "Tocqueville",
    "Victor Hugo",
    "Vilfredo Pareto",
    "Virgil",
    "Voltaire",
    "Walt Whitman",
    "Walter Raleigh",
    "Wentscher",
    "Wilhelm Drobisch",
    "Wilhelm Roscher",
    "Wilhelm von Humboldt",
    "William Caxton",
    "William Godwin",
    "William Graham Sumner",
    "William Harrison",
    "William Harvey",
    "William Penn",
    "William Roper",
    "William Wordsworth",
    "Windelband",
    "Wollstonecraft",
    "Wundt"
]
    

    data = get_ngram_data(
        queries=authors,
        year_start=1945,
        year_end=2019
    )
    
    # Convert to DataFrame
    df = to_dataframe(data)
    print(df.head(10))
    
    # Save to CSV
    df.to_csv(RAW_OUTPUT)
    print("Saved to ngram_raw_schmitt.csv")
