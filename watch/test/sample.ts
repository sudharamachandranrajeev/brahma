// A made-up PropertyPal results page: the same __NEXT_DATA__ shape as the
// real site (fields as seen 2026-10-21), with invented listings.
const centre = { lat: 54.344, lon: -7.638 };

const result = (
  pathId: number,
  displayAddress: string,
  price: number | null,
  numBedrooms: number,
  at: { lat: number; lon: number },
  status = "toLet",
) => ({
  pathId,
  path: `/${displayAddress.toLowerCase().replace(/[^a-z0-9]+/g, "-")}/${pathId}`,
  displayAddress,
  price: price === null ? { priceHidden: true } : { price, priceSuffix: "per month" },
  numBedrooms,
  numBathrooms: 1,
  style: { text: "Apartment" },
  furnishedType: { text: "Furnished" },
  heatingType: { text: "Oil" },
  dateAvailableFrom: "2027-01-01",
  coordinate: { latitude: at.lat, longitude: at.lon },
  account: { organisation: "Example Lettings", officePhone: { international: "+44 28 9649 6000" } },
  images: [{ url: `https://example.com/${pathId}.jpg` }],
  status: { key: status },
});

export const sampleCentre = { ...centre, label: "Town centre" };

export const samplePage = `<html><body><script id="__NEXT_DATA__" type="application/json">${JSON.stringify({
  props: {
    pageProps: {
      initialState: {
        properties: {
          data: {
            totalPages: 2,
            results: [
              result(101, "Apt 1 Sample Street, Enniskillen", 650, 1, { lat: 54.3485, lon: -7.638 }),
              result(102, "2 Sample Road, Enniskillen", 750, 2, { lat: 54.341, lon: -7.642 }),
              result(103, "3 Far Lane, Brookeborough", 550, 2, { lat: 54.316, lon: -7.405 }),
              result(104, "4 Big House Drive, Enniskillen", 1200, 4, { lat: 54.345, lon: -7.63 }),
              result(105, "5 Quiet Court, Enniskillen", null, 1, { lat: 54.346, lon: -7.64 }),
              result(106, "6 Taken Terrace, Enniskillen", 600, 2, { lat: 54.343, lon: -7.636 }, "letAgreed"),
            ],
          },
        },
      },
    },
  },
})}</script></body></html>`;
