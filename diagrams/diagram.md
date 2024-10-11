                            +--------------------+
                            |   Secrets Manager   |
                            |--------------------|           
                            |  - OAuth2 Secrets   |
                            +----------|---------+
                                       |
                                       |
                                       v
                          +----------------------------+
            +------------->|       Lambda Function      |
            |              |----------------------------|
            |  +-----------|  1. Retrieve secrets       |
            |  |           |  2. Make OAuth2 request    |
            |  |           |  3. Get access token       |
            |  |           |  4. Upload to S3           |
            |  |           |  5. Send SNS notification  |
            |  |           +-----------|----------------+
            |  |                       |
            |  |                       v
+----------------------+    +-------------------+   +-------------------+
|  EventBridge (Hourly)|    |    WaterNSW API    |   |       VPC          |
|----------------------|    |-------------------|   |-------------------|
|  - Triggers Lambda   |    |  - OAuth2 token    |   |    S3 Endpoint    |
|    every hour        |    |    request         |   |                   |
+----------------------+    |  - Responds with   |   |                   |
                             |    access token   |   +---------|---------+
                             +-------------------+             |
                                                                |
                                                                v
                                       +-----------------------------+
                                       |         S3 Bucket            |
                                       |-----------------------------|
                                       |  - Stores access token       |
                                       |    in access_token.txt       |
                                       +------------|----------------+
                                                    |
                                                    v
                                       +-----------------------------+
                                       |          SNS Topic           |
                                       |-----------------------------|
                                       |  - Sends notifications       |
                                       |    to your email             |
                                       +-----------------------------+
