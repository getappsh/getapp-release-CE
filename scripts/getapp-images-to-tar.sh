#!/bin/bash

# Define the input file containing the list of Docker images
input_file="getapp-images-list.txt"

if [ -e "$input_file" ]; then
    echo "File $input_file exists in the directory. we are OK to start!"
    echo "seting up some things..."
else
    echo "File $input_file does not exist in the directory."
    echo "this is a file that contains the list of all Docker images of getapp."
    echo "please download the file $input_file from gilab (https://gitlab.getapp.sh/getapp/Main-version-control/getapp-release-versions) and try again."
    exit 1
fi
# Define the output directory for saving individual tar files
current_date=$(date +%d-%m-%y)
echo the current date is: $current_date
output_directory="getapp-$current_date"
echo the output directory is: $output_directory
# Define the output zip file
output_zip="getapp-$current_date.zip"
echo the output zip name will be: $output_zip
echo starting to download the images...
echo this will take some time - depends on your internet speed.
# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file '$input_file' not found."
    exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$output_directory"

# Loop through each line in the input file
while IFS= read -r image; do
    # Check if the image name is not empty
    if [ -n "$image" ]; then
        # Pull the Docker image
        docker pull "$image"
        even_image_tag=$(echo $image | sed 's/harbor\.getapp\.sh\///')
        docker tag "$image" "$even_image_tag"
        echo taged "${image}" as "${even_image_tag}" for easy uploading to even...
        echo saving image ${even_image_tag} to tar file named $(echo ${even_image_tag} | tr / _).tar
        # Save the Docker image to a separate tar file
        output_tar="$output_directory/$(echo "$even_image_tag" | tr / _).tar"
        docker save "$even_image_tag" -o "$output_tar"
    fi
done < "$input_file"

# Zip all tar files into one file
echo saving all tar files to one zip file named $output_zip...
zip -r "$output_zip" "$output_directory"

echo "Docker images saved to the directory'$output_directory' and zipped to '$output_zip'"
