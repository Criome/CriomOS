{
  user,
  ...
}:
{
  config = {
    home = {
      username = user.name;
      homeDirectory = "/home/" + user.name;
      # TODO
      stateVersion = "25.04";
    };
  };
}
