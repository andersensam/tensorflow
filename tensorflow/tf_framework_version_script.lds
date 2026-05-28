VERS_1.0 {
  # Hide libjpeg symbols to avoid symbol conflict with OpenCV
  local:
    *mlir*;
    *EVP_*;
    *HMAC_*;
    *SHA256_*;
    *SSL_*;
    *TLS_*;
};
