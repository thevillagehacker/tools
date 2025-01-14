import pandas as pd
import argparse

def process_excel(input_file, output_file, url_column):
    # Read the Excel file
    df = pd.read_excel(input_file)

    # Validate if the specified URL column exists
    if url_column not in df.columns:
        raise ValueError(f"Column '{url_column}' not found in the file!")

    # Identify all columns except the specified URL column for grouping
    columns_to_group = [col for col in df.columns if col != url_column]

    # Group data, aggregate the specified URL column with comma-separated unique values
    df_grouped = (
        df.groupby(columns_to_group, as_index=False)
        .agg({url_column: lambda x: ', '.join(sorted(set(x)))})
    )

    # Sort the data dynamically based on all columns except the URL column
    df_sorted = df_grouped.sort_values(by=columns_to_group)

    # Save the cleaned and sorted data to a new Excel file
    df_sorted.to_excel(output_file, index=False)

    print(f"Cleaned and sorted data has been saved to '{output_file}'.")

if __name__ == "__main__":
    # Setup argument parser
    parser = argparse.ArgumentParser(description="Process and clean Excel files by grouping and sorting.")
    parser.add_argument("input_file", help="Path to the input Excel file.")
    parser.add_argument("output_file", help="Path to save the cleaned and sorted Excel file.")
    parser.add_argument("url_column", help="Name of the column containing URLs to group.")

    args = parser.parse_args()
        # Add a try-except block to handle errors
    try:
        process_excel(args.input_file, args.output_file, args.url_column)
    except Exception as e:
        print(f"An error occurred: {e}")
