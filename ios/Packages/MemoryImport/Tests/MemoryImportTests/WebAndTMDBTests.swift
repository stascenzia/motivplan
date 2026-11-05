import Foundation
import Testing
@testable import MemoryImport

@Suite("Page web d'une recette")
struct WebRecipeTests {
    @Test("Description schema.org dans un @graph, étapes HowToStep")
    func jsonLD() {
        let html = """
            <html><head><title>Ignoré</title>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@graph":[{"@type":"WebPage","name":"Page"},
             {"@type":"Recipe","name":"Risotto aux champignons","recipeYield":["4","4 portions"],
              "totalTime":"PT1H15M","image":{"url":"https://exemple.fr/risotto.jpg"},
              "recipeIngredient":["300 g de riz arborio","250 g de champignons","1 l de bouillon"],
              "recipeInstructions":[{"@type":"HowToSection","name":"Cuisson","itemListElement":[
                {"@type":"HowToStep","text":"Faire revenir les champignons."},
                {"@type":"HowToStep","text":"Ajouter le riz, puis le bouillon louche par louche."}]}]}]}
            </script></head></html>
            """
        let page = WebRecipeExtractor.extract(html: html)
        #expect(page.title == "Risotto aux champignons")
        #expect(page.recipe?.ingredients == ["300 g de riz arborio", "250 g de champignons", "1 l de bouillon"])
        #expect(page.recipe?.steps == ["Faire revenir les champignons.", "Ajouter le riz, puis le bouillon louche par louche."])
        #expect(page.recipe?.servings == 4)
        #expect(page.recipe?.duration == "1 h 15 min")
        #expect(page.imageURL == URL(string: "https://exemple.fr/risotto.jpg"))
    }

    @Test("Sans description : le titre de la page, entités décodées")
    func titleOnly() {
        let html = #"<head><meta property="og:title" content="Cr&egrave;me br&#251;l&eacute;e &amp; co"><title>x</title></head>"#
        let page = WebRecipeExtractor.extract(html: html)
        #expect(page.title == "Crème brûlée & co")
        #expect(page.recipe == nil)
    }

    @Test("Durées ISO 8601")
    func durations() {
        #expect(WebRecipeExtractor.isoDuration("PT30M") == "30 min")
        #expect(WebRecipeExtractor.isoDuration("PT2H") == "2 h")
        #expect(WebRecipeExtractor.isoDuration("P0DT0H0M") == nil)
    }
}

@Suite("Fiches TMDB")
struct TMDBTests {
    @Test("Recherche multi : films et séries, pas les personnes")
    func search() throws {
        let json = """
            {"page":1,"results":[
             {"id":438631,"media_type":"movie","title":"Dune","release_date":"2021-09-15","overview":"Paul Atréides…","poster_path":"/dune.jpg"},
             {"id":1234,"media_type":"person","name":"Denis Villeneuve"},
             {"id":136315,"media_type":"tv","name":"The Bear","first_air_date":"2022-06-23","overview":"","poster_path":null}]}
            """
        let results = try TMDBDecoding.searchResults(from: Data(json.utf8))
        #expect(results.map(\.id) == ["movie:438631", "tv:136315"])
        #expect(results[0].year == "2021")
        #expect(results[1].title == "The Bear")
        #expect(results[1].overview == nil)
        #expect(results[1].posterPath == nil)
    }

    @Test("Fiche : genres, plateformes de France, champs du modèle")
    func details() throws {
        let json = """
            {"id":136315,"name":"The Bear","first_air_date":"2022-06-23","overview":"Un chef revient à Chicago.",
             "poster_path":"/bear.jpg","genres":[{"id":18,"name":"Drame"},{"id":35,"name":"Comédie"}],
             "number_of_seasons":4,
             "watch/providers":{"results":{"FR":{"flatrate":[{"provider_name":"Disney Plus"}]},
                                            "US":{"flatrate":[{"provider_name":"Hulu"}]}}}}
            """
        let details = try TMDBDecoding.details(from: Data(json.utf8), media: .tv)
        #expect(details.providers == ["Disney Plus"])
        let fields = TMDBMapping.fields(for: details)
        #expect(fields["format"] == "Série")
        #expect(fields["genre"] == "Drame")
        #expect(fields["genres"] == "Drame\nComédie")
        #expect(fields["platform"] == "Disney+")
        #expect(fields["summary"] == "Un chef revient à Chicago.")
        #expect(fields["tmdb"] == "tv:136315")
        #expect(fields["poster"] == "/bear.jpg")
        #expect(fields["seasons"] == "4")

        // Un film n'a pas de saisons, même si la réponse en porte.
        let movie = try TMDBDecoding.details(from: Data(json.utf8), media: .movie)
        #expect(TMDBMapping.fields(for: movie)["seasons"] == nil)
    }

    @Test("Genres et plateformes ramenés aux noms de l'app")
    func mapping() {
        #expect(TMDBMapping.genre(from: ["Science-Fiction & Fantastique", "Drame"]) == "Science-fiction")
        #expect(TMDBMapping.genre(from: ["Crime"]) == "Policier")
        #expect(TMDBMapping.genre(from: ["Western"]) == "Western")
        #expect(TMDBMapping.genre(from: []) == nil)
        #expect(TMDBMapping.platform(from: ["Amazon Prime Video", "Netflix"]) == "Prime Video")
        #expect(TMDBMapping.platform(from: ["Canal+ Séries"]) == "Canal+")
        #expect(TMDBMapping.platform(from: ["Paramount Plus"]) == "Paramount Plus")
        #expect(TMDBMapping.platform(from: ["HBO Max"]) == "HBO Max")
        #expect(TMDBMapping.platform(from: ["Max"]) == "HBO Max")
        #expect(TMDBMapping.platform(from: ["Arte"]) == "Arte")
        #expect(TMDBMapping.platform(from: []) == nil)
    }

    @Test("Requêtes : jeton en en-tête, jamais dans l'adresse")
    func requests() {
        let search = TMDBClient.searchRequest("Dune", token: "secret")
        #expect(search.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(search.url?.absoluteString.contains("secret") == false)
        #expect(search.url?.absoluteString.contains("language=fr-FR") == true)
        let result = TMDBResult(tmdbId: 438631, media: .movie, title: "Dune", year: nil, overview: nil, posterPath: nil)
        let details = TMDBClient.detailsRequest(result, token: "secret")
        #expect(details.url?.path.hasSuffix("/3/movie/438631") == true)
        #expect(details.url?.query?.contains("append_to_response=watch/providers") == true)
    }
}

@Suite("File des partages")
struct PendingImportTests {
    @Test("Déposer, relire dans l'ordre, retirer")
    func queue() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = PendingImportQueue(directory: directory)
        let first = try queue.enqueue(text: "Une recette")
        let second = try queue.enqueue(url: "https://exemple.fr", images: [Data([1, 2, 3]), Data([4])])
        #expect(queue.pending().map(\.id) == [first.id, second.id])
        let images = queue.imageURLs(of: second)
        #expect(images.count == 2)
        let image = try #require(images.first)
        #expect(try Data(contentsOf: image) == Data([1, 2, 3]))
        queue.remove(first)
        queue.remove(second)
        #expect(queue.pending().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: image.path))
    }

    @Test("Sans App Group, pas de file")
    func noGroup() {
        #expect(PendingImportQueue(groupContainer: nil) == nil)
    }
}
