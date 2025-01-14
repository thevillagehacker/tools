import pandas as pd
import argparse
import os

def process_large_file(input_file, output_file, url_column):
    # Determine file type based on the extension
    file_extension = os.path.splitext(input_file)[1].lower()

    # Check for valid file formats
    if file_extension not in ['.xlsx', '.csv']:
        raise ValueError("Unsupported file format. Use an Excel (.xlsx) or CSV (.csv) file.")

    aggregated_data = pd.DataFrame()

    # Chunk processing for CSV files
    if file_extension == '.csv':
        print("Processing large CSV file in chunks...")
        chunk_iter = pd.read_csv(input_file, chunksize=10000)  # Adjust chunk size as needed
        for i, chunk in enumerate(chunk_iter):
            print(f"Processing chunk {i + 1}...")
            print(f"Chunk {i + 1} size: {chunk.shape}")
            print(chunk.head())  # Preview chunk data

            # Ensure the URL column exists in the chunk
            if url_column not in chunk.columns:
                raise ValueError(f"Column '{url_column}' not found in chunk {i + 1}!")

            # Group and aggregate data within each chunk
            chunk_grouped = (
                chunk.groupby(
                    [col for col in chunk.columns if col != url_column], as_index=False
                )
                .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
            )
            print("Sample grouped data in chunk:")
            print(chunk_grouped.head())

            # Append grouped data to the main aggregated DataFrame
            aggregated_data = pd.concat([aggregated_data, chunk_grouped], ignore_index=True)
    else:
        print("Reading and processing Excel file...")
        df = pd.read_excel(input_file)
        
