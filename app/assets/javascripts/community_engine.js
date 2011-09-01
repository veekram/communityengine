//= require prototype
//= require prototype_ujs
//= require effects
//= require builder
//= require dragdrop
//= require controls

//= require lightbox
//= require prototip-min




function scrollToAnchor(anchor){
  loc = document.location.toString();
  if (loc.indexOf("#") != -1){
    parts = loc.split('#')
    loc = parts[0] + '#' + anchor
  } else {
    loc = loc + '#' + anchor
  }
  document.location.href = loc;
}