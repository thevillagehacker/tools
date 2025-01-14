import pandas as pd
import argparse
import os

def process_large_file(input_file, output_file, url_column):
    # Determine file type based on the extension
    file_extension = os.path.splitext(input_file)[1].lower()

    # Check for valid file formats
    if file_extension not in ['.xlsx', '.csv']:
        raise ValueError("Unsupported file format. Use an Excel (.xlsx) or CSV (.csv) file.")

    # Initialize an empty DataFrame to hold grouped results
    aggregated_data = pd.DataFrame()

    # Chunk processing for CSV files
    if file_extension == '.csv':
        print("Processing large CSV file in chunks...")
        chunk_iter = pd.read_csv(input_file, chunksize=10000)  # Adjust chunk size as needed
        for i, chunk in enumerate(chunk_iter):
            print(f"Processing chunk {i + 1}...")
            # Group and aggregate data within each chunk
            chunk_grouped = (
                chunk.groupby(
                    [col for col in chunk.columns if col != url_column], as_index=False
                )
                .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
            )
            # Append grouped data to the main aggregated DataFrame
            aggregated_data = pd.concat([aggregated_data, chunk_grouped], ignore_index=True)
    else:
        print("Reading and processing Excel file...")
        # Read the Excel file
        df = pd.read_excel(input_file)

        # Group data, aggregate the specified URL column with comma-separated unique values
        aggregated_data = (
            df.groupby(
                [col for col in df.columns if col != url_column], as_index=False
            )
            .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
        )

    # Final grouping and sorting after aggregating all chunks
    print("Final grouping and sorting...")
    aggregated_data = (
        aggregated_data.groupby(
            [col for col in aggregated_data.columns if col != url_column], as_index=False
        )
        .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
    )
    aggregated_data = aggregated_data.sort_values(
        by=[col for col in aggregated_data.columns if col != url_column]
    )

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
