import requests
import re
import pandas as pd
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_OUTPUT = ROOT / "data" / "raw" / "ngram_raw_marx.csv"

def get_ngram_data(queries, year_start=1800, year_end=2019, corpus=26, smoothing=0):
    """
    Fetch Google Ngram data for a list of search terms.
    
    queries: list of strings, e.g. ["Carl Schmitt", "Walter Benjamin"]
    corpus: 26 = English (2019)
    """
    
    results = {}
    
    for query in queries:
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
    "Karl Marx",
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
    "Arnold Ruge",
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
    "Bruno Bauer",
    "Bruno Hildebrand",
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
    "Descartes",
    "Dietrich Tiedemann",
    "Dilthey",
    "Dostoyevsky",
    "Dryden",
    "Durkheim",
    "E T A Hoffmann",
    "Ebbinghaus",
    "Edmund Burke",
    "Edmund Spenser",
    "Eduard Beneke",
    "Eduard Bernstein",
    "Eduard Zeller",
    "Eduard von Hartmann",
    "Edward Bellamy",
    "Edward Haies",
    "Edward Jenner",
    "Epictetus",
    "Eugen Dühring",
    "Euripides",
    "Faraday",
    "Ferdinand Lassalle",
    "Ferdinand Tönnies",
    "Fichte",
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
    "Goethe",
    "Gotthold Ephraim Lessing",
    "Gottlob Ernst Schulze",
    "Grimmelshausen",
    "Gustav Freytag",
    "Gustav Schönberg",
    "Hamann",
    "Hans Christian Andersen",
    "Hegel",
    "Heinrich Feder",
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
    "Hölderlin",
    "Immanuel Kant",
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
    "John Ruskin",
    "John Stuart Mill",
    "John Woolman",
    "Jonathan Swift",
    "Joseph Lister",
    "Kafka",
    "Karl Knies",
    "Kelvin",
    "Kempis",
    "Kropotkin",
    "Kuno Fischer",
    "Külpe",
    "Laspeyres",
    "Leibniz",
    "Lord Acton",
    "Lord Byron",
    "Ludwig Büchner",
    "Ludwig Feuerbach",
    "Lujo Brentano",
    "Machiavelli",
    "Mainländer",
    "Malory",
    "Malthus",
    "Marcus Aurelius",
    "Marlowe",
    "Martin Luther",
    "Max Stirner",
    "Mazzini",
    "Molière",
    "Montaigne",
    "Montesquieu",
    "Moses Hess",
    "Moses Mendelssohn",
    "Nassau Senior",
    "Natorp",
    "Newton",
    "Nietzsche",
    "Oliver Goldsmith",
    "Oliver Wendell Holmes",
    "Oscar Wilde",
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
    "Ralph Waldo Emerson",
    "Ranke",
    "Renan",
    "Richard Cobden",
    "Rilke",
    "Robert Browning",
    "Robert Burns",
    "Robert Owen",
    "Rodbertus",
    "Rousseau",
    "Rudolf Haym",
    "Sainte Beuve",
    "Samuel Johnson",
    "Scheler",
    "Schleiermacher",
    "Schmoller",
    "Schopenhauer",
    "Schäffle",
    "Sigismund Beck",
    "Simmel",
    "Simon Newcomb",
    "Sismondi",
    "Sombart",
    "Sophocles",
    "Spinoza",
    "Tacitus",
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
    "Thünen",
    "Tocqueville",
    "Victor Hugo",
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
    "Wundt",
    "de Gouges"
]
    
    data = get_ngram_data(
        queries=authors,
        year_start=1800,
        year_end=2019
    )
    
    # Convert to DataFrame
    df = to_dataframe(data)
    print(df.head(10))
    
    # Save to CSV
    df.to_csv(RAW_OUTPUT)
    print("Saved to ngram_raw_marx.csv")
