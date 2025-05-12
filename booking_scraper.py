import requests
from bs4 import BeautifulSoup
import pandas as pd
import re # Import regex for cleaning price
import random # Importer le module random
import os # Added for path manipulation and directory creation

# Headers to mimic a browser visit
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

def clean_price(price_text):
    if price_text == 'N/A':
        return 'N/A'
    # Remove currency symbols, commas, and other non-numeric characters except decimal point
    # This regex keeps digits and a potential decimal point.
    cleaned = re.sub(r'[^\d.]', '', price_text)
    try:
        # Attempt to convert to float to validate, then return as string or float as needed
        float(cleaned)
        return cleaned 
    except ValueError:
        return 'N/A' # Return 'N/A' if conversion fails

def normalize_rating(score_text):
    if score_text == 'N/A' or not score_text:
        return 'N/A'
    try:
        score = float(score_text.replace(',', '.')) # Handle comma as decimal separator
        normalized_score = score / 2.0
        # Clamp the score between 1 and 5
        clamped_score = max(1.0, min(normalized_score, 5.0))
        return f"{clamped_score:.1f}" # Format to one decimal place
    except ValueError:
        return 'N/A'

try:    
    def get_url_for_city(city_name, dest_id):
        return f"https://www.booking.com/searchresults.en-gb.html?ss={city_name}&dest_id={dest_id}&dest_type=city&group_adults=2&no_rooms=1&group_children=0&aid=2311236&lang=en-gb&sb=1&src_elem=sb&src=searchresults"

    output_directory = r"d:\PFA\flutter_application_1\assets"
    output_filename = "marrakech_hotels.csv"
    global_output_file_path = os.path.join(output_directory, output_filename)

    if not os.path.exists(output_directory):
        os.makedirs(output_directory)
        print(f"Created directory: {output_directory}")

    # MODIFIED: Liste contenant uniquement Casablanca, Fes, Tanger, Agadir, Rabat.
    # Vérifiez et mettez à jour les dest_id si nécessaire.
    cities_to_scrape = [
        # Villes Marocaines spécifiées
        {"name": "Casablanca", "dest_id": "-14763"},
        {"name": "Fes", "dest_id": "-24307"},
        {"name": "Tangier", "dest_id": "-59010"},
        {"name": "Agadir", "dest_id": "-2906"},
        {"name": "Rabat", "dest_id": "-48901"},
        
        # Les autres villes marocaines et internationales sont maintenant commentées ou supprimées
        # {"name": "Marrakech", "dest_id": "-38833"},
        # {"name": "Essaouira", "dest_id": "-23017"},
        # {"name": "Meknes", "dest_id": "-39062"},
        # {"name": "Oujda", "dest_id": "-44778"},
        # {"name": "Chefchaouen", "dest_id": "-16582"},
        # {"name": "Ifrane", "dest_id": "-30014"},
        
        # {"name": "Paris", "dest_id": "-1456928"},
        # {"name": "Istanbul", "dest_id": "-755070"},
        # {"name": "Rome", "dest_id": "-126693"},
        # {"name": "Dubai", "dest_id": "-782831"},
        # {"name": "NewYork", "dest_id": "20088325"},
        # {"name": "London", "dest_id": "-2601889"},
    ]

    all_hotels_data = []
    predefined_features_list = ['Wifi', 'Piscine', 'Spa', 'Restaurant', 'Parking', 'Gym', 'Vue mer', 'Pet-friendly', 'Navette aéroport', 'Bar', 'Climatisation']


    for city_info in cities_to_scrape:
        current_city_name = city_info["name"]
        current_dest_id = city_info["dest_id"]
        
        url = get_url_for_city(current_city_name, current_dest_id)
        print(f"Scraping hotels for {current_city_name} from {url}")

        try:
            response = requests.get(url, headers=headers, timeout=20) # Added timeout
            response.raise_for_status() 
        except requests.exceptions.RequestException as e:
            print(f"Could not fetch URL {url}: {e}")
            continue # Skip to next city if fetching fails
    
        soup = BeautifulSoup(response.text, 'html.parser')
        hotels_data_current_city = []
        hotel_entries = soup.find_all('div', {'data-testid': 'property-card'})
    
        for hotel in hotel_entries:
            name = hotel.find('div', class_='b87c397a13').get_text(strip=True) if hotel.find('div', class_='b87c397a13') else 'N/A'
            description_element = hotel.find('div', class_='abf093bdfe')
            description = description_element.get_text(strip=True) if description_element else 'N/A'

            score_element = hotel.find('div', {'data-testid': 'review-score'}) 
            score_text_from_site = 'N/A'
            if score_element:
                actual_score_div = score_element.find('div', class_='b0b8de40e6')
                if actual_score_div:
                    score_text_from_site = actual_score_div.get_text(strip=True)
            
            normalized_review_score = normalize_rating(score_text_from_site)
            if normalized_review_score == 'N/A':
                normalized_review_score = f"{random.uniform(2.5, 4.9):.1f}" # Adjusted random rating

            rating_text_element = hotel.find('div', class_='f7385d32fa')
            rating_text = rating_text_element.get_text(strip=True) if rating_text_element else 'N/A'
            if score_text_from_site != 'N/A' and rating_text == 'N/A' and score_element:
                 review_word_element = score_element.find('div', class_='f7385d32fa')
                 if review_word_element:
                     rating_text = review_word_element.get_text(strip=True)

            cleaned_price = f"{random.randint(50, 500)}.{random.randint(0,99):02d}"
            phone_number = f"0{random.choice([5, 6, 7])}{random.randint(10000000, 99999999):08d}"
            distance_element = hotel.find('span', {'data-testid': 'distance'})
            distance = distance_element.get_text(strip=True) if distance_element else 'N/A'
            
            # MODIFIED: Facilities/Equipements extraction and generation
            facilities_text_scraped = 'N/A'
            facilities_element = hotel.find('div', class_='d22a7c133b') # Adjust selector if needed
            
            parsed_facilities = []
            if facilities_element:
                # Try to find individual facility items, often in spans or small divs
                items = facilities_element.find_all(['span', 'div'], class_=re.compile(r'.*facility.*|.*amenity.*'), recursive=True) # More generic class search
                if not items: # Fallback if specific class not found
                    items = facilities_element.find_all(['span','div'], recursive=False)

                for item_tag in items:
                    item_text = item_tag.get_text(strip=True)
                    if item_text and len(item_text) > 2 and len(item_text) < 50: # Basic filter for relevance
                        parsed_facilities.append(item_text)
                
                if parsed_facilities:
                    facilities_text_scraped = ', '.join(list(set(parsed_facilities))[:5]) # Take unique, max 5 scraped
                elif facilities_element.get_text(strip=True): # Fallback to the whole text
                    facilities_text_scraped = facilities_element.get_text(separator=', ', strip=True)
            
            final_facilities_string = ''
            if facilities_text_scraped != 'N/A' and parsed_facilities:
                final_facilities_string = facilities_text_scraped
            else: # If no facilities scraped or only 'N/A', assign random ones
                num_random_features = random.randint(2, 5) # Add 2 to 5 random features
                random_selected_features = random.sample(predefined_features_list, num_random_features)
                final_facilities_string = ', '.join(random_selected_features)


            image_element = hotel.find('img', {'data-testid': 'image'}) 
            image_url = image_element['src'] if image_element and image_element.has_attr('src') else 'N/A'
            
            city = current_city_name
            date_scraped = pd.Timestamp.now().strftime('%Y-%m-%d')

            hotels_data_current_city.append({
                'Nom_Hotel': name,
                'Description': description,
                'Note': normalized_review_score, 
                'Evaluation_Textuelle': rating_text,
                'Prix': cleaned_price, 
                'Telephone': phone_number, 
                'Distance': distance,
                'Equipements': final_facilities_string, # Use the processed string
                'Image_URL': image_url,
                'Ville': city,
                'Date_Extraction': date_scraped
            })
        
        if hotels_data_current_city:
            all_hotels_data.extend(hotels_data_current_city)
            print(f"Extracted {len(hotels_data_current_city)} hotels for {current_city_name}.")
        else:
            print(f"Aucun hôtel trouvé pour {current_city_name}.")
    
    if all_hotels_data:
        df_all_hotels = pd.DataFrame(all_hotels_data)
        column_order = [
            'Nom_Hotel', 'Description', 'Note', 'Evaluation_Textuelle', 'Prix', 
            'Telephone', 'Distance', 'Equipements', 'Image_URL', 'Ville', 'Date_Extraction'
        ]
        for col in column_order:
            if col not in df_all_hotels.columns:
                df_all_hotels[col] = 'N/A' 
        df_all_hotels = df_all_hotels[column_order]
        
        df_all_hotels.to_csv(global_output_file_path, index=False, encoding='utf-8')
        print(f"All hotel data successfully extracted and saved to '{global_output_file_path}'")
        print(f"Total number of hotels extracted: {len(all_hotels_data)}")
    else:
        print("No hotel data was extracted from any city.")
    
except requests.exceptions.RequestException as e:
    print(f"Erreur lors de la récupération de la page: {e}")
except Exception as e:
    print(f"Une erreur s'est produite: {e}")