
import urllib.request
import re
import numpy as np
import pandas as pd
import time
import tqdm

def from_html_to_dict(html_station_string):
    result = re.findall(r'VALUES\[\d+\] = new Array\("\d+","\d+/\d+/\d+","\d+.\d+","\d*.*\d*"\)', html_station_string)
    station_day = {}
    for entry in result:
        parts = entry.split('"')
        date = parts[3]
        value = float(parts[7]) if parts[7] else 0.0
        station_day[date] = value
    return station_day

def fetch_station_data(station_ids):
    htmls = {}
    for stazione in tqdm.tqdm(np.unique(station_ids)):
        retries = 1
        success = False
        while not success:
            try:
                url = f"http://www.sir.toscana.it/monitoraggio/dettaglio.php?id={stazione}&title=&type=pluvio_men"
                with urllib.request.urlopen(url) as fp:
                    htmls[stazione] = fp.read().decode("utf8")
                success = True
            except Exception as e:
                wait = retries * 10
                print(e)
                print(f"Error! Waiting {wait} secs and re-trying...")
                time.sleep(wait)
    return htmls

def main():
    # Read the cleaned station metadata
    stazioni = pd.read_csv("assets/stazioni.csv", sep=";")
    stazioni = stazioni.drop_duplicates(subset="IDStazione")
    stazioni.set_index("IDStazione", inplace=True)

    # Fetch data
    htmls = fetch_station_data(stazioni.index)

    # Parse all HTMLs
    dati_stazioni = {id_: from_html_to_dict(htmls[id_]) for id_ in htmls}

    # Assemble final dataframe
    dati_pandas = pd.DataFrame.from_dict(dati_stazioni, orient="index")
    dati_completi = pd.concat([stazioni, dati_pandas], axis=1)
    dati_completi = dati_completi.drop(columns=[
        'Fiume', 'Provincia', 'Comune', 'StazioneExtra',
        'Strumento', 'QuotaTerra', 'IDSensoreRete'
    ], errors='ignore')
    dati_completi.fillna(0, inplace=True)

    # Save result
    dati_completi.to_csv("assets/dati_completi.csv", encoding="utf8", index=False)
    print("✅ File saved to assets/dati_completi.csv")

if __name__ == "__main__":
    main()
