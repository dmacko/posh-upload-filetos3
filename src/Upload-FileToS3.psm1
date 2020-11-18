$scriptPath = $(Split-Path -parent $MyInvocation.MyCommand.Definition)


Function Upload-FileToS3
{
    param (
        [Parameter(Mandatory=$True,
        HelpMessage='The path of the file to upload')]
        [string]$Path,
        [Parameter(Mandatory=$True,
        HelpMessage='The API Key ID to use')]
        [string]$ApiKey,
        [Parameter(Mandatory=$True,
        HelpMessage='The API Key Secret to use')]
        [string]$ApiSecret,
        [Parameter(Mandatory=$True,
        HelpMessage='The s3 key to use e.g. prefix/my_backup_file.zip')]
        [string]$S3Key,
        [Parameter(Mandatory=$True,
        HelpMessage='The amazon S3 folder (bucket name + prefix) that the path should be uploaded to')]
        [string]$S3Bucket
    )

    Add-Type -Path "$scriptPath\AWSSDK.Core.dll"
    Add-Type -Path "$scriptPath\AWSSDK.s3.dll"

    $logfile = "$scriptPath\Upload-FileToS3.log"
    "" | Out-File $logfile -Encoding ascii

    $s3Config = New-Object Amazon.S3.AmazonS3Config
    $s3Config.MaxErrorRetry = 50
	
	#todo: allow this to be set via an input param
    $s3Config.RegionEndpoint = [Amazon.RegionEndpoint]::APSoutheast2

    $s3Client = New-Object Amazon.S3.AmazonS3Client -ArgumentList $ApiKey, $ApiSecret, $s3Config
	
	$file = $Path | Get-Item
	
	if ($file.Length -le 5 * 1024 * 1024) 
	{
        # file size is less than 5MB - do a single part upload
        $request = New-Object Amazon.S3.Model.PutObjectRequest
        $request.BucketName = $S3Bucket
        $request.Key = $S3Key
        $request.FilePath = $Path

        $s3Client.PutObject($request)
	}
	else
    {
        #file size is greater than 5MB - do a multipart upload
        $partSize = 5 * 1024 * 1024
        $uploadResponses = @()

        #initiate the multipart upload
        $initRequest = New-Object Amazon.S3.Model.InitiateMultipartUploadRequest
        $initRequest.BucketName = $S3Bucket
        $initRequest.Key = $S3Key

        $initResponse = $s3Client.InitiateMultipartUpload($initRequest)

        try
        {
            $filePosition = 0
            for ($i = 1; $filePosition -lt $file.Length; $i++)
            {
                Add-Content -Path $logfile -Value "Uploading $S3Key part no: $i..." -Encoding Ascii

                $uploadRequest = New-Object Amazon.S3.Model.UploadPartRequest
                $uploadRequest.BucketName = $S3Bucket
                $uploadRequest.Key = $S3Key
                $uploadRequest.UploadId = $initResponse.UploadId
                $uploadRequest.PartNumber = $i
                $uploadRequest.PartSize = $partSize
                $uploadRequest.FilePosition = $filePosition
                $uploadRequest.FilePath = $Path

                $uploadResponses +=($s3Client.UploadPart($uploadRequest))

                $filePosition += $partSize
            }

            $completeRequest = New-Object Amazon.S3.Model.CompleteMultipartUploadRequest
            $completeRequest.BucketName = $S3Bucket
            $completeRequest.Key = $S3Key
            $completeRequest.UploadId = $initResponse.UploadId

            $uploadResponses | ForEach-Object { $completeRequest.PartETags.Add((New-Object Amazon.S3.Model.PartETag -ArgumentList $_.PartNumber, $_.ETag)) }

            $completeResponse = $s3Client.CompleteMultipartUpload($completeRequest)

            Add-Content -Path $logfile -Value "Upload completed" -Encoding Ascii
        }
        catch
        {
            $abortRequest = New-Object Amazon.S3.Model.AbortMultipartUploadRequest
            $abortRequest.BucketName = $S3Bucket
            $abortRequest.Key = $S3Key
            $abortRequest.UploadId = $initResponse.UploadId

            $abortResponse = $s3Client.AbortMultipartUpload($abortRequest)

            Add-Content -Path $logfile -Value $_ -Encoding Ascii
            Add-Content -Path $logfile -Value "Abort response code: $($abortResponse.HttpStatusCode)" -Encoding Ascii

            throw $_
        }
    }
}