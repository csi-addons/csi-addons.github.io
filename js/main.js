// Mobile navigation toggle
document.addEventListener("DOMContentLoaded", function () {
  var navToggle = document.getElementById("nav-toggle");
  var navLinks = document.getElementById("nav-links");
  var navbar = document.getElementById("navbar");

  // Mobile menu toggle
  navToggle.addEventListener("click", function () {
    navLinks.classList.toggle("open");
  });

  // Close mobile menu on link click
  navLinks.querySelectorAll("a").forEach(function (link) {
    link.addEventListener("click", function () {
      navLinks.classList.remove("open");
    });
  });

  // Navbar scroll shadow
  window.addEventListener("scroll", function () {
    if (window.scrollY > 10) {
      navbar.classList.add("scrolled");
    } else {
      navbar.classList.remove("scrolled");
    }
  });

  // Tab switching
  var tabButtons = document.querySelectorAll(".tab-btn");
  tabButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
      var tabId = btn.getAttribute("data-tab");

      tabButtons.forEach(function (b) {
        b.classList.remove("active");
      });
      btn.classList.add("active");

      document.querySelectorAll(".tab-content").forEach(function (content) {
        content.classList.remove("active");
      });
      document.getElementById("tab-" + tabId).classList.add("active");
    });
  });

  // Copy button functionality
  document.querySelectorAll(".copy-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var targetId = btn.getAttribute("data-target");
      var code = document.getElementById(targetId).textContent;
      navigator.clipboard.writeText(code).then(function () {
        var original = btn.textContent;
        btn.textContent = "Copied!";
        setTimeout(function () {
          btn.textContent = original;
        }, 2000);
      });
    });
  });
});
