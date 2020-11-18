# posh-upload-filetos3
Reliable, portable Powershell module to upload a file to Amazon S3. 
This is basically a wrapper around the .NET AWS SDK, with some extra logic around multipart uploads and error retries


#Usage

```powershell
# optional - compress the file prior before uploading it. 7zip is used here because Compress-Archive runs out of memory for big files
& "$scriptPath\lib\7za.exe" a -tzip "c:\file_to_upload.zip" c:\file_to_upload.bak

Import-Module ".\Upload-FileToS3.psm1" -DisableNameChecking
Upload-FileToS3 -Path "c:\file_to_upload.zip" -S3Bucket my_s3_bucket -ApiKey AMAZON_API_KEY -ApiSecret $config.S3Config.AccessKey -S3Key $s3Key
```

#Known issues
The AWS region is currently hardcoded to AP-Southeast-2 within Upload-FileToS3.psm1, so you'll need to edit it to match the region you're using.
A list of region names can be found here: https://docs.aws.amazon.com/sdkfornet/v3/apidocs/items/Amazon/TRegionEndpoint.html

This script uses multipart uploading, which has implications if you're making use of S3's ETags.

#Why?
I needed the ability to upload files from various windows machines to Amazon S3. 
Existing tools to do this, such as s3.exe or AWS tools for Powershell were not sufficiently portable or reliable, especially in situations where the files were large and the internet connection was poor.

This script should be compatible with most post-XP windows machines, and should also work even if you're trying to send a 10GB file via avian carrier.

#Licensing
This powershell module is released with the Unlicence. For convenience, the source also includes binaries for the Amazon .NET SDK, and 7zip, which are redistributed under their own respective licences.