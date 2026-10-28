{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Miky8745";
        email = "mikulas.vanecek@gmail.com";
      };
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };
}
