// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// FleetMap Hook for Leaflet integration
const FleetMap = {
  mounted() {
    this.map = null;
    this.vehicleMarkers = new Map();
    this.geofenceLayers = new Map();

    // Wait for Leaflet to be loaded
    if (typeof L !== 'undefined') {
      this.initializeMap();
    } else {
      // Retry after a short delay if Leaflet isn't loaded yet
      setTimeout(() => this.initializeMap(), 100);
    }
  },

  updated() {
    if (this.map) {
      this.updateVehicles();
      this.updateGeofences();
    }
  },

  destroyed() {
    if (this.map) {
      this.map.remove();
    }
  },

  initializeMap() {
    if (typeof L === 'undefined') {
      console.error('Leaflet not loaded');
      return;
    }

    // Initialize map centered on San Francisco
    this.map = L.map(this.el).setView([37.7749, -122.4194], 12);

    // Add OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 19
    }).addTo(this.map);

    // Add vehicle markers and geofences
    this.updateVehicles();
    this.updateGeofences();

    console.log('Fleet map initialized');
  },

  updateVehicles() {
    const vehicles = JSON.parse(this.el.dataset.vehicles || '[]');

    // Clear existing markers
    this.vehicleMarkers.forEach(marker => this.map.removeLayer(marker));
    this.vehicleMarkers.clear();

    // Add new markers
    vehicles.forEach(vehicle => {
      const marker = L.marker([vehicle.location.lat, vehicle.location.lng])
        .addTo(this.map)
        .bindPopup(`<b>Vehicle ${vehicle.id}</b><br>Speed: ${vehicle.speed} km/h`);

      this.vehicleMarkers.set(vehicle.id, marker);
    });
  },

  updateGeofences() {
    const geofences = JSON.parse(this.el.dataset.geofences || '[]');

    // Clear existing geofence layers
    this.geofenceLayers.forEach(layer => this.map.removeLayer(layer));
    this.geofenceLayers.clear();

    // Add new geofence layers
    geofences.forEach(geofence => {
      if (geofence.boundary && geofence.boundary.type === 'Polygon') {
        const coordinates = geofence.boundary.coordinates[0].map(coord => [coord[1], coord[0]]); // Convert from [lng, lat] to [lat, lng]

        const polygon = L.polygon(coordinates, {
          color: 'blue',
          weight: 2,
          opacity: 0.8,
          fillColor: 'blue',
          fillOpacity: 0.1
        })
        .addTo(this.map)
        .bindPopup(`<b>${geofence.name}</b><br>Type: ${geofence.type}`);

        this.geofenceLayers.set(geofence.id, polygon);
      }
    });
  }
};

// Register the hook
let Hooks = {};
Hooks.FleetMap = FleetMap;

// Update LiveSocket configuration
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

