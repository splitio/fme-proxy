package org.example;


import org.apache.hc.client5.http.auth.AuthScope;
import org.apache.hc.client5.http.auth.BearerToken;
import org.apache.hc.client5.http.auth.Credentials;
import org.apache.hc.core5.http.protocol.HttpContext;

class DynamicCredentials implements  org.apache.hc.client5.http.auth.CredentialsProvider {

    @Override
    public Credentials getCredentials(AuthScope authScope, HttpContext context) {

        // This Provider is invoked every time a request is made.
        // This should invoke a user-custom provider responsible for:
        // - checking if there's a cached token
        // - - If so, check it's validity and if ok, return it
        // - get hold of a new token (by whathever method the client decides to do so)
        // - cache it for future use
        // - remove it.

        return new BearerToken("eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImRjNDViOGNhLTA5YTktNGE4Ny1iM2ZlLWE1Y2VmOThjZjRlMCJ9.eyJpc3MiOiJPbmxpbmUgSldUIEJ1aWxkZXIiLCJpYXQiOjE3NDg1NTY1NjYsImV4cCI6MTc4MDA5MjU2NiwiYXVkIjoid3d3LmV4YW1wbGUuY29tIiwic3ViIjoianJvY2tldEBleGFtcGxlLmNvbSIsIkdpdmVuTmFtZSI6IkpvaG5ueSIsIlN1cm5hbWUiOiJSb2NrZXQiLCJFbWFpbCI6Impyb2NrZXRAZXhhbXBsZS5jb20ifQ.ChYHOWme7zT0WxLt31ks-zf6ltgNmh9s4bYUcpIITf2oJKBlWnVmZHEMHn28P7uIqx0oBfiiC7WVATDfzswAKOQCgCexw1kK6Rk6fCx6dgKNih4tf8LzIVn0eq3p5hP_ClnWvpd4hxX34IWP6lD2-BBgs2lMEKX6wseRtcghp7mEK1hpbwO3PUq_Ir89vTOuK4OYyUH1Iz7ak2VOu7V1VKJmL2S5bEi2b3a6CXRfEi-rBPjKArFSOPlQT5Xfl6lHVXTeNGfQjGShapJDlH7Esu4VQ4afwiKmM7vefvKIFeTzBX1Uhw73K6ZJ18bCTmVbzvvYEgz7gWj2aDsRKE7UnA");
    }

}

