import os
import requests
from tqdm import tqdm

def ensure_download():
    url = "https://deprived.dev/assets/school/un-general-debates.csv"
    dest_folder = "../data"
    dest_path = os.path.join(dest_folder, "un-general-debates.csv")

    os.makedirs(dest_folder, exist_ok=True)

    if os.path.exists(dest_path):
        print(f"dataset already exists: {dest_path}")
    else:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        # total file size
        total_size = int(response.headers.get('content-length', 0))
        block_size = 1024 

        with open(dest_path, "wb") as f, tqdm(
            desc="Downloading hema data",
            total=total_size,
            unit='iB',
            unit_scale=True,
            unit_divisor=1024,
        ) as bar:
            for data in response.iter_content(block_size):
                size = f.write(data)
                bar.update(size)

        print("dataset download complete!")
        
        
if __name__ == '__main__':
    ensure_download()