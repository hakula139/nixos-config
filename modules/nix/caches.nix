{
  cachixCacheName,
  cachixPublicKey,
}:
let
  cachixCacheUrl = "https://${cachixCacheName}.cachix.org";
in
{
  substituters = [ cachixCacheUrl ];
  trusted-public-keys = [ cachixPublicKey ];
}
