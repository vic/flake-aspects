# Core aspect resolution algorithm
# Resolves aspect definitions into nixpkgs modules with dependency resolution

lib: namespace:
let
  filePath = class: segments: "${namespace}:${lib.concatStringsSep "." segments}.${class}";

  build =
    file: class: chain: segments: provided:
    let
      fileAttr = if provided ? _file then provided._file else null;
      computedFile = if fileAttr == null then file else fileAttr;
    in
    {
      _file = computedFile;
      imports = lib.flatten [
        {
          _file = computedFile;
          imports = [ (provided.${class} or { }) ];
        }
        (lib.imap0 (includeAt class chain segments) (provided.includes or [ ]))
      ];
    };

  includeAt =
    class: chain: segments: idx: provider:
    let
      provided = provider {
        aspect-chain = chain;
        inherit class;
      };
      chain' = chain ++ [ provided ];
      name = provided.name or "<anonymous>";
      segments' = segments ++ [
        "includes[${toString idx}]"
        name
      ];
      file = filePath class segments';
    in
    build file class chain' segments' provided;

  resolve =
    class: aspect-chain: provided:
    let
      chain = aspect-chain ++ [ provided ];
      segments = [ (provided.name or "<anonymous>") ];
    in
    build (filePath class segments) class chain segments provided;

in
resolve
