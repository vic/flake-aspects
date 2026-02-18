lib:
# An utility for creating new aspect configuration classes that
# help with separation of concerns.
#
# `forward` is a function that generates an aspect
# that imports configurations from an originClass into
# an scoped submodule of another targetClass.
#
# It takes te following arguments:
#
#  - each: listOf items.
#  - fromClass: item -> originClassName.
#  - intoClass: item -> targetClassName.
#  - intoPath: item -> [ submoduleAttrPath ].
#  - fromAspect: item -> aspect. An aspect to resolve origin class modules from.
#
# This is particularly useful for per-user homeManager like
# configurations.
#
# The following pseudo-code snippet is used by [den](https://github.com/vic/den)
# to support homeManager classes on NixOS.
#
#   hmSupport = { host }: forward {
#     each = host.users;
#     fromClass = _user: "homeManager"; # originClass could have depended on user.
#     intoClass = _user: "nixos"
#     intoPath = user: [ "home-manager" "users" user.userName ] # HM users submodule.
#     fromAspect = user: den.aspects.${user.userName}; # resolve originClass from user aspect.
#   }
#
#
#   den.aspects.my-host.includes = [ hmSupport ];
#   den.aspects.my-user = {
#     homeManager = { }; # settings for nixos.home-manager.users.my-user submodule.
#   }
#
# However usage is not limited to HM, and this settings forwarding ability
# can be used for other use cases.
#
# See checkmate/modules/tests/forward.nix for working example.
#
{
  each,
  fromClass,
  intoClass,
  intoPath,
  fromAspect,
}:
let
  include =
    item:
    let
      from = fromClass item;
      into = intoClass item;
      path = intoPath item;
      aspect = fromAspect item;
      module = aspect.resolve { class = from; };
      config = lib.setAttrByPath path (
        { ... }:
        {
          imports = [ module ];
        }
      );
    in
    {
      ${into} = config;
    };
in
{
  includes = map include each;
}
