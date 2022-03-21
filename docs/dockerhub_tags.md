# Available Image Tags
The `latest` tag will always build the head of the
[master branch][master-branch], so please use a more specific one if you can
since master should not be considered "stable".

All the tags since `2.0.0` are built for the following architectures:

- linux/amd64
- linux/386 (:warning: not available for [Alpine][alpine-i386] since Nginx `v1.21.0`)
- linux/arm64
- linux/arm/v7

and it is possible to append `-alpine` to any tag from `2.0.1` to get an Alpine
based image instead. The less specific tags will move as those more specific
are updated.


| Major | Minor | Patch | Nginx              |
| ----: | ----: | ----: | :----------------- |
| 3     | 3.1   | 3.1.1 | 3.1.1-nginx1.21.6  |
|       |       | 3.1.0 | 3.1.0-nginx1.21.6  |
|       | 3.0   | 3.0.1 | 3.0.1-nginx1.21.6  |
|       |       |       | 3.0.1-nginx1.21.5  |
|       |       |       | 3.0.1-nginx1.21.4  |
|       |       |       | 3.0.1-nginx1.21.3  |
|       |       | 3.0.0 | 3.0.0-nginx1.21.3  |
| 2     | 2.4   | 2.4.1 | 2.4.1-nginx1.21.3  |
|       |       |       | 2.4.1-nginx1.21.1  |
|       |       |       | 2.4.1-nginx1.21.0  |
|       |       | 2.4.0 | 2.4.0-nginx1.21.0  |
|       | 2.3   | 2.3.0 | 2.3.0-nginx1.21.0  |
|       | 2.2   | 2.2.0 | 2.2.0-nginx1.21.0  |
|       |       |       | 2.2.0-nginx1.19.10 |
|       | 2.1   | 2.1.0 | 2.1.0-nginx1.19.10 |
|       | 2.0   | 2.0.1 | 2.0.1-nginx1.19.10 |
|       |       | 2.0.0 | 2.0.0-nginx1.19.10 |
|       |       | 1.3.0 | 1.3.0-nginx1.19.10 |
|       |       |       | 1.3.0-nginx1.19.9  |
|       |       | 1.2.0 | 1.2.0-nginx1.19.9  |
|       |       |       | 1.2.0-nginx1.19.8  |
|       |       | 1.1.0 | 1.1.0-nginx1.19.8  |
|       |       |       | 1.1.0-nginx1.19.7  |
|       |       | 1.0.0 | 1.0.0-nginx1.19.7  |

[master-branch]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master
[alpine-i386]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/77
