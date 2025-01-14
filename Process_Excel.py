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
            print(f"\nProcessing chunk {i + 1}...")
            print(f"Chunk {i + 1} size: {chunk.shape}")
            print("Chunk column names:", chunk.columns)

            # Ensure the URL column exists in the chunk
            if url_column not in chunk.columns:
                raise ValueError(f"Column '{url_column}' not found in chunk {i + 1}!")

            # Check for missing values in the url_column
            missing_values_count = chunk[url_column].isna().sum()
            print(f"Missing values in '{url_column}': {missing_values_count}")

            # Drop rows where the URL column is NaN
            chunk = chunk.dropna(subset=[url_column])

            if chunk.empty:
                print(f"Chunk {i + 1} is empty after removing NaN values in '{url_column}'")
                continue

            # Group and aggregate data within each chunk
            chunk_grouped = (
                chunk.groupby(
                    [col for col in chunk.columns if col != url_column], as_index=False
                )
                .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
            )
            print(f"Sample grouped data in chunk {i + 1}:")
            print(chunk_grouped.head())

            # Append grouped data to the main aggregated DataFrame
            aggregated_data = pd.concat([aggregated_data, chunk_grouped], ignore_index=True)
    else:
        print("Reading and processing Excel file...")
        df = pd.read_excel(input_file)
        print("Column names in the Excel file:", df.columns)

        # Ensure the URL column exists
        if url_column not in df.columns:
            raise ValueError(f"Column '{url_column}' not found in the Excel file!")

        # Check for missing values in the url_column
        missing_values_count = df[url_column].isna().sum()
        print(f"Missing values in '{url_column}': {missing_values_count}")

        # Drop rows where the URL column is NaN
        df = df.dropna(subset=[url_column])

        if df.empty:
            print(f"File is empty after removing NaN values in '{url_column}'")
            return

        # Group data, aggregate the specified URL column with comma-separated unique values
        aggregated_data = (
            df.groupby(
                [col for col in df.columns if col != url_column], as_index=False
            )
            .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
        )
        print("Sample grouped data from the Excel file:")
        print(aggregated_data.head())

    # Final grouping and sorting after aggregating all chunks
    print("\nFinal grouping and sorting...")
    if not aggregated_data.empty:
        aggregated_data = (
            aggregated_data.groupby(
                [col for col in aggregated_data.columns if col != url_column], as_index=False
            )
            .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
        )
        aggregated_data = aggregated_data.sort_values(
            by=[col for col in aggregated_data.columns if col != url_column]
        )
    else:
        print("Warning: No data was processed from the file.")

    print("Final aggregated data preview:")
    print(aggregated_data.head())

    # Save the cleaned and sorted data based on the desired output format
    output_extension = os.path.splitext(output_file)[1].lower()
    if output_extension == '.xlsx':
        print("Saving to Excel file...")
        aggregated_data.to_excel(output_file, index=False)
    elif output_extension == '.csv':
        print("Saving to CSV file...")
        aggregated_data.to_csv(output_file, index=False)
    else:
        raise ValueError("Unsupported output file format. Use an Excel (.xlsx) or CSV (.csv) file.")

    print(f"Cleaned and sorted data has been saved to '{output_file}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process and clean large Excel or CSV files by grouping and sorting.")
    parser.add_argument("input_file", help="Path to the input file (Excel or CSV).")
    parser.add_argument("output_file", help="Path to save the cleaned and sorted file (Excel or CSV).")
    parser.add_argument("url_column", help="Name of the column containing URLs to group.")

    args = parser.parse_args()

    try:
        process_large_file(args.input_file, args.output_file, args.url_column)
    except Exception as e:
        print(f"An error occurred: {e}")
