use myntra;
select COUNT(*) from products;


#-----------------------------------------------------Revenue Analysis-------------------------------------------------------------#
#1. Find the top 3 revenue-generating products in each category where category revenue exceeds the average category revenue.
WITH CategoryRevenue AS(
	SELECT
		Product_category,
		SUM(Revenue) AS TotalRevenue
	FROM products
	GROUP BY Product_category
	HAVING SUM(Revenue)>
		(
			SELECT ROUND(AVG(CategoryRevenue),2)
			FROM (
					SELECT SUM(Revenue) AS CategoryRevenue
					FROM products
					GROUP BY Product_category
				 ) x
		)
),
RankedProducts AS(
SELECT
	RANK() OVER(
				PARTITION BY Product_category
				ORDER BY Revenue DESC
			   ) AS ranking,
	Product_category,
	product_name,
	Revenue
FROM products
                        
)
SELECT *
FROM RankedProducts
WHERE Product_category IN(
	SELECT Product_category
	FROM CategoryRevenue
						 )
AND ranking <= 3;

#_________________________________________________________________________________________________________________________________________________#
#2. Find brands whose total revenue is above average brand revenue and rank them by revenue.
SELECT RANK() OVER(ORDER BY Rev DESC) AS Ranking,
	   Brand,
       Rev
FROM (
	SELECT brand_name AS Brand,
		   SUM(Revenue) AS Rev
	FROM products
	GROUP BY Brand
	HAVING SUM(Revenue) > (
		SELECT AVG(Rev)
		FROM (
			SELECT brand_name AS Brand,
				   SUM(Revenue) AS Rev
			FROM products
			GROUP BY Brand
			 ) X
						 )
) X
ORDER BY Rev DESC;

#_________________________________________________________________________________________________________________________________________________#
#3. Find products contributing to the top 20% of total revenue using cumulative revenue.
WITH product_cumulative AS (
    SELECT
        product_name,
        brand_name,
        Product_category,
        Revenue,
        SUM(Revenue) OVER (
            ORDER BY Revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        )                               AS cumulative_revenue,
        SUM(Revenue) OVER ()            AS total_revenue
    FROM products
),
with_pct AS (
    SELECT
        product_name,
        brand_name,
        Product_category,
        ROUND(Revenue, 2)                                           AS Revenue,
        ROUND(cumulative_revenue, 2)                               AS cumulative_revenue,
        ROUND(total_revenue, 2)                                    AS total_revenue,
        ROUND(cumulative_revenue * 100.0 / total_revenue, 2)       AS cumulative_pct
    FROM product_cumulative
)
SELECT
    product_name,
    brand_name,
    Product_category,
    Revenue,
    cumulative_revenue,
    cumulative_pct
FROM with_pct
WHERE cumulative_pct <= 20
ORDER BY Revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#4. Find categories whose revenue contribution exceeds 5% of overall revenue.
SELECT *
FROM (
	WITH total_revenue AS (
		SELECT SUM(Revenue) AS grand_total
		FROM products
	)
	SELECT
		Product_category,
		ROUND(SUM(Revenue), 2)  AS Categories_Revenue,
		ROUND(SUM(Revenue) * 100.0 / tr.grand_total, 2) AS Contribution
	FROM products
	CROSS JOIN total_revenue tr
	GROUP BY Product_category, tr.grand_total
	ORDER BY Contribution DESC
) x
WHERE Categories_Revenue > (
	SELECT 0.05*SUM(Revenue) 
	FROM products
);

#_________________________________________________________________________________________________________________________________________________#
#5. Find the second highest revenue-generating product in each category.
WITH ranked AS (
	SELECT
		Product_category,
		product_name,
		Revenue,
        DENSE_RANK() OVER (
			PARTITION BY Product_category
			ORDER BY Revenue DESC
		) AS rnk
	FROM products
)
SELECT
	Product_category,
    product_name,
	Revenue
FROM ranked
WHERE rnk = 2
ORDER BY Revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#6. Find brands whose revenue is greater than the average revenue of the top 10 brands.
WITH brand_revenue AS (
	SELECT brand_name,
		   SUM(Revenue) AS total_revenue
	FROM products
	GROUP BY brand_name
),
top10 AS (
	SELECT total_revenue
	FROM brand_revenue
	ORDER BY total_revenue DESC
	LIMIT 10
),
top10_avg AS (
	SELECT AVG(total_revenue) AS avg_revenue
	FROM top10
)
SELECT br.brand_name,
	   ROUND(br.total_revenue, 2) AS total_revenue
FROM brand_revenue br
CROSS JOIN top10_avg t
WHERE br.total_revenue > t.avg_revenue
ORDER BY br.total_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#7. Find categories where average product revenue exceeds overall average revenue.
WITH overall_avg AS (
    SELECT AVG(Revenue) AS avg_revenue
    FROM products
),
category_avg AS (
    SELECT
        Product_category,
        AVG(Revenue) AS avg_category_revenue
    FROM products
    GROUP BY Product_category
)
SELECT
    ca.Product_category,
    ROUND(ca.avg_category_revenue, 2) AS avg_category_revenue
FROM category_avg ca
CROSS JOIN overall_avg oa
WHERE ca.avg_category_revenue > oa.avg_revenue
ORDER BY ca.avg_category_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#8. Find products generating more revenue than the average product in their category.
WITH category_avg AS (
    SELECT
        Product_category,
        AVG(Revenue) AS avg_category_revenue
    FROM products
    GROUP BY Product_category
)
SELECT
    p.Product_category,
    p.product_name,
    ROUND(p.Revenue, 2) AS Revenue,
    ROUND(ca.avg_category_revenue, 2) AS category_avg_revenue
FROM products p
JOIN category_avg ca
    ON p.Product_category = ca.Product_category
WHERE p.Revenue > ca.avg_category_revenue
ORDER BY p.Product_category, p.Revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#9. Find top 5 brands within each category based on revenue.
WITH brand_category_revenue AS (
    SELECT
        Product_category,
        brand_name,
        SUM(Revenue) AS total_revenue
    FROM products
    GROUP BY Product_category, brand_name
),
ranked AS (
    SELECT
        Product_category,
        brand_name,
        total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY Product_category
            ORDER BY total_revenue DESC
						  ) AS rnk
    FROM brand_category_revenue
)
SELECT
    Product_category,
    brand_name,
    ROUND(total_revenue, 2) AS total_revenue,
    rnk
FROM ranked
WHERE rnk <= 5
ORDER BY Product_category, rnk;

#_________________________________________________________________________________________________________________________________________________#
#10. Find categories where top product contributes more than 30% of category revenue.
WITH category_total AS (
    SELECT
        Product_category,
        SUM(Revenue) AS total_category_revenue
    FROM products
    GROUP BY Product_category
),
top_product AS (
    SELECT
        Product_category,
        product_name,
        Revenue,
        DENSE_RANK() OVER (
            PARTITION BY Product_category
            ORDER BY Revenue DESC
		) AS rnk
    FROM products
)
SELECT
    tp.Product_category,
    tp.product_name,
    ROUND(tp.Revenue, 2) AS top_product_revenue,
    ROUND(ct.total_category_revenue, 2) AS category_revenue,
    ROUND(tp.Revenue * 100.0 / ct.total_category_revenue, 2) AS contribution_pct
FROM top_product tp
JOIN category_total ct
    ON tp.Product_category = ct.Product_category
WHERE tp.rnk = 1
  AND tp.Revenue * 100.0 / ct.total_category_revenue > 30
ORDER BY contribution_pct DESC;

#_________________________________________________________________________________________________________________________________________________#
#11. Find products whose revenue is above the median revenue of their category.
WITH ranked AS (
    SELECT
        Product_category,
        product_name,
        brand_name,
        Revenue,
        ROW_NUMBER() OVER (
			PARTITION BY Product_category 
            ORDER BY Revenue
		) AS rn,
        COUNT(*) OVER (
            PARTITION BY Product_category
		) AS cnt
    FROM products
),
category_median AS (
    SELECT
        Product_category,
        AVG(Revenue) AS median_revenue
    FROM ranked
    WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
    GROUP BY Product_category
)
SELECT
    m.Product_category,
    m.product_name,
    ROUND(m.Revenue, 2) AS Revenue,
    ROUND(cm.median_revenue, 2) AS category_median_revenue
FROM products m
JOIN category_median cm
    ON m.Product_category = cm.Product_category
WHERE m.Revenue > cm.median_revenue
ORDER BY m.Product_category, m.Revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#12. Find the top 10 products contributing maximum cumulative revenue.
SELECT
    rn AS Ranking,
    product_name,
    brand_name,
    Product_category,
    ROUND(Revenue, 2) AS Revenue,
    ROUND(cumulative_revenue, 2) AS cumulative_revenue
FROM (
    SELECT
        product_name,
        brand_name,
        Product_category,
        Revenue,
        ROW_NUMBER() OVER (ORDER BY Revenue DESC) AS rn,
        SUM(Revenue) OVER (ORDER BY Revenue DESC) AS cumulative_revenue
    FROM products
	) AS ranked
WHERE rn <= 10
ORDER BY rn;
#_________________________________________________________________________________________________________________________________________________#

#13. Find brands generating revenue greater than the combined revenue of bottom 50% brands.
WITH brand_revenue AS (
						SELECT
							brand_name,
							SUM(Revenue) AS total_revenue
						FROM products
						GROUP BY brand_name
),
ranked AS (
			SELECT
				brand_name,
				total_revenue,
				ROW_NUMBER() OVER (ORDER BY total_revenue ASC) AS rn,
				COUNT(*) OVER () AS total_brands
			FROM brand_revenue
),
bottom_half_sum AS (
					SELECT
						SUM(total_revenue) AS bottom50_revenue
					FROM ranked
					WHERE rn <= CEIL(total_brands * 0.5)
)
SELECT
    br.brand_name,
    ROUND(br.total_revenue, 2) AS total_revenue,
    ROUND(bh.bottom50_revenue, 2) AS bottom50_combined_revenue
FROM brand_revenue br
CROSS JOIN bottom_half_sum bh
WHERE br.total_revenue > bh.bottom50_revenue
ORDER BY br.total_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#14. Find categories whose total revenue is more than twice the average category revenue.
WITH category_revenue AS (
							SELECT
								Product_category,
								SUM(Revenue) AS total_revenue
							FROM products
							GROUP BY Product_category
),
avg_category_revenue AS (
							SELECT
								AVG(total_revenue) AS avg_revenue
							FROM category_revenue
)
SELECT
    cr.Product_category,
    ROUND(cr.total_revenue, 2) AS total_revenue,
    ROUND(acr.avg_revenue, 2) AS avg_category_revenue,
    ROUND(cr.total_revenue / acr.avg_revenue, 2) AS times_avg
FROM category_revenue cr
CROSS JOIN avg_category_revenue acr
WHERE cr.total_revenue > 2 * acr.avg_revenue
ORDER BY cr.total_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#15. Find products ranked in the top 10% revenue across all products.
SELECT product_name,
       ROUND(Revenue, 2) AS Revenue
FROM (
	SELECT
		product_name,
		Revenue,
		NTILE(10) OVER (ORDER BY Revenue DESC) AS decile
	FROM products
) AS ranked
WHERE decile = 1
ORDER BY Revenue DESC;
#_________________________________________________________________________________________________________________________________________________#
#-------------------------------------Rating Analysis (16–30)------------------------------------------#
#16 Find highest-rated product in each category where category average rating exceeds 4.2.
WITH category_avg_rating AS (
    SELECT
        Product_category,
        AVG(rating) AS avg_rating
    FROM products
    GROUP BY Product_category
    HAVING AVG(rating) > 4.2
),

ranked AS (
    SELECT p.Product_category,
		   p.product_name,
		   p.rating,
		   DENSE_RANK() OVER (
			PARTITION BY p.Product_category
			ORDER BY p.rating DESC
		   ) AS rnk
    FROM products p
    JOIN category_avg_rating car
        ON p.Product_category = car.Product_category
)
SELECT
    Product_category,
    product_name,
    rating
FROM ranked
WHERE rnk = 1
ORDER BY rating;

#_________________________________________________________________________________________________________________________________________________#
#17 Find brands having more than 20 products and average rating above overall average rating.
SELECT
    brand_name,
    COUNT(*) AS product_count,
    ROUND(AVG(rating), 2) AS avg_brand_rating
FROM products
GROUP BY brand_name
HAVING COUNT(*) > 20
   AND AVG(rating) > (SELECT AVG(rating) FROM products)
ORDER BY avg_brand_rating DESC;

#_________________________________________________________________________________________________________________________________________________#
#18 Find top 3 products by rating_count in each category.
WITH ranked AS (
				SELECT
					Product_category,
					product_name,
					rating_count,
					ROW_NUMBER() OVER (PARTITION BY Product_category ORDER BY rating_count DESC) AS rn
				FROM products
)
SELECT
    Product_category,
    product_name,
    rating_count
FROM ranked
WHERE rn <= 3
ORDER BY Product_category, rn;

#_________________________________________________________________________________________________________________________________________________#
#19 Find products whose rating is higher than category average rating.
WITH category_avg_rating AS (
	SELECT
		Product_category,
		AVG(rating) AS avg_category_rating
	FROM products
	GROUP BY Product_category
)
SELECT 
	p.Product_category,
	p.product_name,
	p.rating,
	ROUND(cat.avg_category_rating, 2) AS avg_category_rating
FROM products p
JOIN category_avg_rating cat
    ON p.Product_category = cat.Product_category
WHERE p.rating > cat.avg_category_rating
ORDER BY p.Product_category, p.rating DESC;

#_________________________________________________________________________________________________________________________________________________#
#20 Find brands whose average rating exceeds average rating of top 10 brands by revenue.
WITH brand_revenue AS (
	SELECT
		brand_name,
		SUM(Revenue) AS total_revenue,
		AVG(rating) AS avg_brand_rating
	FROM products
	GROUP BY brand_name
),
top10_brands AS (
	SELECT brand_name, avg_brand_rating
	FROM brand_revenue
	ORDER BY total_revenue DESC
	LIMIT 10
),
top10_avg_rating AS (
	SELECT AVG(avg_brand_rating) AS benchmark_rating
	FROM top10_brands
)
SELECT br.brand_name,
       ROUND(br.avg_brand_rating, 2) AS avg_brand_rating,
       ROUND(t.benchmark_rating, 2) AS top10_benchmark_rating
FROM brand_revenue br
CROSS JOIN top10_avg_rating t
WHERE br.avg_brand_rating > t.benchmark_rating
ORDER BY br.avg_brand_rating DESC;

#__________________________________________________________________________________________________________________________________________________#
#21 Find categories where more than 70% products have ratings above 4.
WITH brand_revenue AS (
	SELECT
		brand_name,
		SUM(Revenue) AS total_revenue,
		AVG(rating) AS avg_brand_rating
	FROM products
	GROUP BY brand_name
),
top10_brands AS (
	SELECT brand_name, avg_brand_rating
	FROM brand_revenue
	ORDER BY total_revenue DESC
	LIMIT 10
),
top10_avg_rating AS (
	SELECT AVG(avg_brand_rating) AS benchmark_rating
	FROM top10_brands
)
SELECT
    br.brand_name,
    ROUND(br.avg_brand_rating, 2) AS avg_brand_rating,
    ROUND(t.benchmark_rating, 2) AS top10_benchmark_rating
FROM brand_revenue br
CROSS JOIN top10_avg_rating t
WHERE br.avg_brand_rating > t.benchmark_rating
ORDER BY br.avg_brand_rating DESC;

#__________________________________________________________________________________________________________________________________________________#
#22 Find products having rating_count greater than category average rating_count.
WITH category_avg_rc AS (
	SELECT
		Product_category,
		AVG(rating_count) AS avg_rating_count
	FROM products
	GROUP BY Product_category
)
SELECT
    p.Product_category,
    p.product_name,
    p.rating_count,
    ROUND(cat.avg_rating_count, 2) AS avg_category_rating_count
FROM products p
JOIN category_avg_rc cat
    ON p.Product_category = cat.Product_category
WHERE p.rating_count > cat.avg_rating_count
ORDER BY p.Product_category, p.rating_count DESC;

#_________________________________________________________________________________________________________________________________________________#
#23 Find brands with highest-rated product in every category.
WITH category_max_rating AS (
    SELECT
        Product_category,
        MAX(rating) AS max_rating
    FROM products
    GROUP BY Product_category
),
top_rated_per_category AS (
    SELECT DISTINCT
        p.Product_category,
        p.brand_name
    FROM products p
    JOIN category_max_rating cmr
        ON p.Product_category = cmr.Product_category
        AND p.rating = cmr.max_rating
),
category_count AS (
    SELECT COUNT(DISTINCT Product_category) AS total_categories
    FROM products
)
SELECT
    tr.brand_name,
    COUNT(DISTINCT tr.Product_category) AS categories_topped
FROM top_rated_per_category tr
CROSS JOIN category_count cc
GROUP BY tr.brand_name, cc.total_categories
HAVING COUNT(DISTINCT tr.Product_category) = cc.total_categories
ORDER BY tr.brand_name;

#24 Find categories whose median rating exceeds overall median rating.
WITH product_positions AS (
	SELECT Product_category,
		   rating,
		   ROW_NUMBER() OVER (
			PARTITION BY Product_category
			ORDER BY rating
							 ) AS rn,
		   COUNT(*) OVER (
			PARTITION BY Product_category
						 ) AS cnt
	FROM products
),
category_median AS (
	SELECT
		Product_category,
		AVG(rating) AS median_rating
	FROM product_positions
	WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
	GROUP BY Product_category
),
overall_positions AS (
	SELECT
		rating,
		ROW_NUMBER() OVER (ORDER BY rating) AS rn,
		COUNT(*) OVER () AS cnt
	FROM products
),
overall_median AS (
	SELECT AVG(rating) AS median_rating
	FROM overall_positions
	WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
)
SELECT
    cm.Product_category,
    ROUND(cm.median_rating, 2) AS category_median_rating
FROM category_median cm
CROSS JOIN overall_median om
WHERE cm.median_rating > om.median_rating
ORDER BY cm.median_rating DESC;
#_________________________________________________________________________________________________________________________________________________#
#25 Find top-rated product among brands generating above-average revenue.
WITH brand_revenue AS (
	SELECT
		brand_name,
		SUM(Revenue) AS total_revenue
	FROM products
	GROUP BY brand_name
),
avg_brand_revenue AS (
	SELECT AVG(total_revenue) AS avg_revenue
	FROM brand_revenue
),
above_avg_brands AS (
	SELECT br.brand_name
	FROM brand_revenue br
	CROSS JOIN avg_brand_revenue abr
	WHERE br.total_revenue > abr.avg_revenue
),
ranked AS (
	SELECT
		m.product_name,
		m.brand_name,
		m.Product_category,
		m.rating,
		m.Revenue,
		DENSE_RANK() OVER (ORDER BY m.rating DESC) AS rnk
	FROM products m
	JOIN above_avg_brands aab
		ON m.brand_name = aab.brand_name
)
SELECT
    product_name,
    brand_name,
    Product_category,
    rating,
    ROUND(Revenue, 2) AS Revenue
FROM ranked
WHERE rnk = 1
ORDER BY Revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#26 Find brands having at least 5 products rated above 4.5.

WITH high_rated AS (
	SELECT
		brand_name,
		COUNT(*) AS products_above_4_5
	FROM products
	WHERE rating > 4.5
	GROUP BY brand_name
)
SELECT
    brand_name,
    products_above_4_5
FROM high_rated
WHERE products_above_4_5 >= 5
ORDER BY products_above_4_5 DESC;

#_________________________________________________________________________________________________________________________________________________#
#27 Find products ranked between 5th and 10th position by rating within each category.
WITH ranked AS (
	SELECT
		Product_category,
		product_name,
		rating,
		DENSE_RANK() OVER (
			PARTITION BY Product_category
			ORDER BY rating DESC
		) AS rnk
	FROM products
)
SELECT
    Product_category,
    product_name,
    rating,
    rnk
FROM ranked
WHERE rnk BETWEEN 5 AND 10
ORDER BY Product_category, rnk;

#_________________________________________________________________________________________________________________________________________________#
#28 Find categories where maximum rating_count exceeds category average by 5 times.
WITH category_stats AS (
	SELECT
		Product_category,
		MAX(rating_count) AS max_rating_count,
		AVG(rating_count) AS avg_rating_count
	FROM products
	GROUP BY Product_category
)
SELECT
    Product_category,
    ROUND(max_rating_count, 2) AS max_rating_count,
    ROUND(avg_rating_count, 2) AS avg_rating_count,
    ROUND(max_rating_count / avg_rating_count, 2) AS times_avg
FROM category_stats
WHERE max_rating_count > 5 * avg_rating_count
ORDER BY times_avg DESC;
#_________________________________________________________________________________________________________________________________________________#
#29 Find categories where top-rated product contributes over 20% of total ratings.
WITH category_stats AS (
	SELECT
		Product_category,
		SUM(rating_count)  AS total_rating_count,
		MAX(rating)        AS max_rating
	FROM products
	GROUP BY Product_category
),
top_rated AS (
	SELECT
		p.Product_category,
		p.product_name,
		p.brand_name,
		p.rating,
		p.rating_count,
		DENSE_RANK() OVER (
			PARTITION BY p.Product_category
			ORDER BY p.rating DESC
		) AS rnk
	FROM products p
)
SELECT
    tr.Product_category,
    tr.product_name,
    tr.rating,
    tr.rating_count                                               AS top_product_rating_count,
    cs.total_rating_count,
    ROUND(tr.rating_count * 100.0 / cs.total_rating_count, 2)    AS contribution_pct
FROM top_rated tr
JOIN category_stats cs
    ON tr.Product_category = cs.Product_category
WHERE tr.rnk = 1
  AND tr.rating_count * 100.0 / cs.total_rating_count > 20
ORDER BY contribution_pct;
#_________________________________________________________________________________________________________________________________________________#
#30 Find categories where more than 40% brands have ratings above 3.5
WITH BrandRatings AS (
    SELECT 
        Product_category,
        brand_name,
        AVG(rating) AS avg_brand_rating
    FROM products
    GROUP BY Product_category, brand_name
),
HighRatedBrands AS (
    SELECT 
        Product_category,
        COUNT(brand_name) AS high_rated_count
    FROM BrandRatings
    WHERE avg_brand_rating > 3.5
    GROUP BY Product_category
),
TotalBrandsPerCategory AS (
    SELECT 
        Product_category,
        COUNT(brand_name) AS total_count
    FROM BrandRatings
    GROUP BY Product_category
)
SELECT 
    t.Product_category,
    t.total_count AS total_brands,
    h.high_rated_count AS brands_above_35,
    (h.high_rated_count * 100.0) / t.total_count AS percentage_eligible_brands
FROM TotalBrandsPerCategory t
JOIN HighRatedBrands h ON t.Product_category = h.Product_category
WHERE (h.high_rated_count * 100.0) / t.total_count > 40.0
ORDER BY percentage_eligible_brands DESC;


#-------------------------------------------------Discount & Pricing Analysis---------------------------------------------------#
#31. Find products whose discount exceeds category average discount.
WITH category_avg_discount AS (
    SELECT
        Product_category,
        AVG(`Discount%`) AS avg_discount
    FROM products
    GROUP BY Product_category
)
SELECT
    p.Product_category,
    p.product_name,
    p.`Discount%`                       AS product_discount,
    ROUND(cad.avg_discount, 2)          AS avg_category_discount
FROM products p
JOIN category_avg_discount cad
    ON p.Product_category = cad.Product_category
WHERE p.`Discount%` > cad.avg_discount
ORDER BY p.Product_category, p.`Discount%` DESC;

#_________________________________________________________________________________________________________________________________________________#
#32. Find top 5 most discounted products in each category.
WITH ranked AS (
    SELECT
        Product_category,
        product_name,
        `Discount%`,
        rating,
        DENSE_RANK() OVER (
            PARTITION BY Product_category
            ORDER BY `Discount%` DESC
        ) AS rnk
    FROM products
)
SELECT
    Product_category,
    product_name,
    `Discount%`,
    rating,
    rnk
FROM ranked
WHERE rnk <= 5
ORDER BY Product_category, rnk;
#_________________________________________________________________________________________________________________________________________________#
#33. Find categories having average discount greater than overall average discount.
WITH overall_avg_discount AS (
    SELECT AVG(`Discount%`) AS avg_discount
    FROM products
),
category_avg_discount AS (
    SELECT
        Product_category,
        AVG(`Discount%`) AS avg_category_discount
    FROM products
    GROUP BY Product_category
)
SELECT
    cad.Product_category,
    ROUND(cad.avg_category_discount, 2) AS avg_category_discount,
    ROUND(oad.avg_discount, 2)          AS overall_avg_discount
FROM category_avg_discount cad
CROSS JOIN overall_avg_discount oad
WHERE cad.avg_category_discount > oad.avg_discount
ORDER BY cad.avg_category_discount DESC;

#_________________________________________________________________________________________________________________________________________________#
#34. Find brands whose average discounted price exceeds category average discounted price.
WITH category_avg_price AS (
    SELECT
        Product_category,
        AVG(discounted_price) AS avg_category_price
    FROM products
    GROUP BY Product_category
),
brand_avg_price AS (
    SELECT
        Product_category,
        brand_name,
        AVG(discounted_price) AS avg_brand_price
    FROM products
    GROUP BY Product_category, brand_name
)
SELECT
    bp.Product_category,
    bp.brand_name,
    ROUND(bp.avg_brand_price, 2)    AS avg_brand_price,
    ROUND(cp.avg_category_price, 2) AS avg_category_price
FROM brand_avg_price bp
JOIN category_avg_price cp
    ON bp.Product_category = cp.Product_category
WHERE bp.avg_brand_price > cp.avg_category_price
ORDER BY bp.Product_category, bp.avg_brand_price DESC;

#_________________________________________________________________________________________________________________________________________________#
#35. Find products price above category median price.
 WITH price_positions AS (
    SELECT
        Product_category,
        product_name,
        discounted_price,
        ROW_NUMBER() OVER (
            PARTITION BY Product_category
            ORDER BY discounted_price
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY Product_category
        ) AS cnt
    FROM products
),
category_median_price AS (
    SELECT
        Product_category,
        AVG(discounted_price) AS median_price
    FROM price_positions
    WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
    GROUP BY Product_category
)
SELECT
    p.Product_category,
    p.product_name,
    ROUND(p.discounted_price, 2)    AS discounted_price,
    ROUND(cmp.median_price, 2)      AS category_median_price
FROM products p
JOIN category_median_price cmp
    ON p.Product_category = cmp.Product_category
WHERE p.discounted_price > cmp.median_price
ORDER BY p.Product_category, p.discounted_price DESC;

#_________________________________________________________________________________________________________________________________________________#
#36. Find categories where more than 50% products have discounts above 40%.
WITH category_stats AS (
    SELECT
        Product_category,
        COUNT(*) AS total_products,
        SUM(CASE WHEN `Discount%` > 40 THEN 1 ELSE 0 END)  AS high_discount_count
    FROM products
    GROUP BY Product_category
)
SELECT
    Product_category,
    total_products,
    high_discount_count,
    ROUND(high_discount_count * 100.0 / total_products, 2) AS pct_above_40
FROM category_stats
WHERE high_discount_count * 100.0 / total_products > 50
ORDER BY pct_above_40 DESC;

#_________________________________________________________________________________________________________________________________________________#
#37. Find brands with highest average discount among brands having at least 100 products.
WITH brand_stats AS (
    SELECT
        brand_name,
        COUNT(*) AS product_count,
        AVG(`Discount%`)    AS avg_discount
    FROM products
    GROUP BY brand_name
),
qualified_brands AS (
    SELECT
        brand_name,
        product_count,
        avg_discount
    FROM brand_stats
    WHERE product_count >= 100
),
max_discount AS (
    SELECT MAX(avg_discount) AS highest_avg_discount
    FROM qualified_brands
)
SELECT
    qb.brand_name,
    qb.product_count,
    ROUND(qb.avg_discount, 2)           AS avg_discount,
    ROUND(md.highest_avg_discount, 2)   AS highest_avg_discount
FROM qualified_brands qb
CROSS JOIN max_discount md
WHERE qb.avg_discount = md.highest_avg_discount
ORDER BY qb.avg_discount DESC;

#_________________________________________________________________________________________________________________________________________________#
#38. Find categories where maximum discount exceeds average discount by more than 30%.
WITH category_stats AS (
    SELECT
        Product_category,
        MAX(`Discount%`) AS max_discount,
        AVG(`Discount%`) AS avg_discount
    FROM products
    GROUP BY Product_category
)
SELECT
    Product_category,
    ROUND(max_discount, 2)              AS max_discount,
    ROUND(avg_discount, 2)             AS avg_discount,
    ROUND(max_discount - avg_discount, 2) AS discount_spread
FROM category_stats
WHERE max_discount - avg_discount > 30
ORDER BY discount_spread DESC;

#_________________________________________________________________________________________________________________________________________________#
#39. Find products ranked by discount within category.
WITH ranked AS (
    SELECT
        Product_category,
        product_name,
        `Discount%`,
        discounted_price,
        DENSE_RANK() OVER (
            PARTITION BY Product_category
            ORDER BY `Discount%` DESC
        ) AS discount_rank
    FROM products
)
SELECT
    Product_category,
    product_name,
    `Discount%`,
    discounted_price,
    discount_rank
FROM ranked
ORDER BY Product_category, discount_rank;
#_________________________________________________________________________________________________________________________________________________#
#40. Find categories whose average marked price exceeds overall average marked price.
WITH overall_avg_price AS (
    SELECT AVG(marked_price) AS avg_marked_price
    FROM products
),
category_avg_price AS (
    SELECT
        Product_category,
        AVG(marked_price) AS avg_category_price
    FROM products
    GROUP BY Product_category
)
SELECT
    cap.Product_category,
    ROUND(cap.avg_category_price, 2)    AS avg_category_price,
    ROUND(oap.avg_marked_price, 2)      AS overall_avg_price
FROM category_avg_price cap
CROSS JOIN overall_avg_price oap
WHERE cap.avg_category_price > oap.avg_marked_price
ORDER BY cap.avg_category_price DESC;

#_________________________________________________________________________________________________________________________________________________#
#41. Find brands where average selling price is less than 60% of average MRP.
WITH brand_price_stats AS (
    SELECT
        brand_name,
        AVG(discounted_price) AS avg_selling_price,
        AVG(marked_price)     AS avg_mrp
    FROM products
    GROUP BY brand_name
)
SELECT
    brand_name,
    ROUND(avg_selling_price, 2) AS avg_selling_price,
    ROUND(avg_mrp, 2)           AS avg_mrp,
    ROUND(avg_selling_price * 100.0 / avg_mrp, 2) AS selling_price_pct_of_mrp
FROM brand_price_stats
WHERE avg_selling_price < 0.6 * avg_mrp
ORDER BY selling_price_pct_of_mrp ASC;

#_________________________________________________________________________________________________________________________________________________#
#42. Find categories where products ranked by revenue have increasing discount percentages
WITH revenue_ranked AS (
    SELECT
        Product_category,
        `Discount%`,
        NTILE(4) OVER (
            PARTITION BY Product_category
            ORDER BY Revenue ASC
        ) AS revenue_quartile
    FROM products
),
quartile_avg AS (
    SELECT
        Product_category,
        revenue_quartile,
        AVG(`Discount%`) AS avg_discount
    FROM revenue_ranked
    GROUP BY Product_category, revenue_quartile
),
quartile_with_lag AS (
    SELECT
        Product_category,
        revenue_quartile,
        ROUND(avg_discount, 2) AS avg_discount,
        LAG(avg_discount) OVER (
            PARTITION BY Product_category
            ORDER BY revenue_quartile
        ) AS prev_avg_discount
    FROM quartile_avg
),
category_trend AS (
    SELECT
        Product_category,
        SUM(CASE WHEN prev_avg_discount IS NULL
                   OR avg_discount > prev_avg_discount
                 THEN 1 ELSE 0 END) AS increasing_steps,
        COUNT(*)                     AS total_steps
    FROM quartile_with_lag
    GROUP BY Product_category
)
SELECT Product_category
FROM category_trend
WHERE increasing_steps = total_steps
ORDER BY Product_category;

#_________________________________________________________________________________________________________________________________________________#
#43. Find products contributing to top 10% discounts overall.
WITH ranked AS (
    SELECT
        product_name,
        `Discount%`,
        discounted_price,
        NTILE(10) OVER (
            ORDER BY `Discount%` DESC
        ) AS decile
    FROM products
)
SELECT
    product_name,
    `Discount%`,
    discounted_price
FROM ranked
WHERE decile = 1
ORDER BY `Discount%` DESC;

#_________________________________________________________________________________________________________________________________________________#
#44. Find brands having average discount greater than top 20 revenue-generating brands.
WITH brand_stats AS (
    SELECT
        brand_name,
        SUM(Revenue)        AS total_revenue,
        AVG(`Discount%`)    AS avg_discount
    FROM products
    GROUP BY brand_name
),
top20_brands AS (
    SELECT avg_discount
    FROM brand_stats
    ORDER BY total_revenue DESC
    LIMIT 20
),
top20_avg_discount AS (
    SELECT AVG(avg_discount) AS benchmark_discount
    FROM top20_brands
)
SELECT
    bs.brand_name,
    ROUND(bs.avg_discount, 2)           AS avg_discount,
    ROUND(t.benchmark_discount, 2)      AS top20_benchmark_discount,
    ROUND(bs.total_revenue, 2)          AS total_revenue
FROM brand_stats bs
CROSS JOIN top20_avg_discount t
WHERE bs.avg_discount > t.benchmark_discount
ORDER BY bs.avg_discount DESC;

#_________________________________________________________________________________________________________________________________________________#
#45. Find categories where discounted price variance exceeds overall variance.
WITH overall_variance AS (
    SELECT VAR_POP(discounted_price) AS overall_var
    FROM products
),
category_variance AS (
    SELECT
        Product_category,
        VAR_POP(discounted_price) AS category_var,
        AVG(discounted_price) AS avg_price,
        COUNT(*) AS product_count
    FROM products
    GROUP BY Product_category
)
SELECT
    cv.Product_category,
    ROUND(cv.category_var, 2)       AS category_variance,
    ROUND(ov.overall_var, 2)        AS overall_variance,
    ROUND(cv.avg_price, 2)          AS avg_discounted_price,
    cv.product_count,
    ROUND(cv.category_var / ov.overall_var, 2) AS times_overall_var
FROM category_variance cv
CROSS JOIN overall_variance ov
WHERE cv.category_var > ov.overall_var
ORDER BY cv.category_var DESC;

#_________________________________________________________________________________________________________________________________________________#
#46. Find top 3 brands in every category by revenue.
WITH brand_category_revenue AS (
    SELECT
        Product_category,
        brand_name,
        SUM(Revenue) AS total_revenue
    FROM products
    GROUP BY Product_category, brand_name
),
ranked AS (
    SELECT
        Product_category,
        brand_name,
        total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY Product_category
            ORDER BY total_revenue DESC
        ) AS rnk
    FROM brand_category_revenue
)
SELECT
    Product_category,
    brand_name,
    ROUND(total_revenue, 2) AS total_revenue,
    rnk
FROM ranked
WHERE rnk <= 3
ORDER BY Product_category, rnk;

#_________________________________________________________________________________________________________________________________________________#
#47. Find categories where brand contributes more than 40% category revenue.
SELECT
    Product_category,
    brand_name,
    ROUND(brand_revenue, 2) AS brand_revenue,
    ROUND(total_category_revenue, 2) AS total_category_revenue,
    ROUND(brand_revenue * 100.0 / total_category_revenue, 2) AS contribution_pct
FROM (
    SELECT
        bcr.Product_category,
        bcr.brand_name,
        bcr.brand_revenue,
        SUM(bcr.brand_revenue) OVER 
        (
            PARTITION BY bcr.Product_category
        )                                                       AS total_category_revenue,
        DENSE_RANK() OVER 
        (
            PARTITION BY bcr.Product_category
            ORDER BY bcr.brand_revenue DESC
        )                                                       AS rnk
    FROM (
        SELECT
            Product_category,
            brand_name,
            SUM(Revenue) AS brand_revenue
        FROM products
        GROUP BY Product_category, brand_name
    ) AS bcr
) AS ranked
WHERE rnk = 1
  AND brand_revenue * 100.0 / total_category_revenue > 40
ORDER BY contribution_pct;

#_________________________________________________________________________________________________________________________________________________#
#48. Find brands appearing in top 10 by both revenue and rating.
WITH brand_stats AS (
    SELECT
        brand_name,
        SUM(Revenue) AS total_revenue,
        AVG(rating) AS avg_rating
    FROM products
    GROUP BY brand_name
),
top10_revenue AS (
    SELECT brand_name
    FROM brand_stats
    ORDER BY total_revenue DESC
    LIMIT 10
),
top10_rating AS (
    SELECT brand_name
    FROM brand_stats
    ORDER BY avg_rating DESC
    LIMIT 10
)
SELECT
    bs.brand_name,
    ROUND(bs.total_revenue, 2)  AS total_revenue,
    ROUND(bs.avg_rating, 2)     AS avg_rating
FROM brand_stats bs
WHERE bs.brand_name IN (SELECT brand_name FROM top10_revenue)
  AND bs.brand_name IN (SELECT brand_name FROM top10_rating)
ORDER BY bs.total_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#49. Find categories with more products than average category product count.
WITH category_count AS (
    SELECT
        Product_category,
        COUNT(*) AS product_count
    FROM products
    GROUP BY Product_category
),
overall_avg AS (
    SELECT AVG(product_count) AS avg_product_count
    FROM category_count
)
SELECT
    cc.Product_category,
    cc.product_count,
    ROUND(oa.avg_product_count, 2) AS avg_category_count
FROM category_count cc
CROSS JOIN overall_avg oa
WHERE cc.product_count > oa.avg_product_count
ORDER BY cc.product_count DESC;

#_________________________________________________________________________________________________________________________________________________#
#50. Find brands whose product count exceeds category average product count.
WITH brand_product_count AS (
    SELECT
        Product_category,
        brand_name,
        COUNT(*) AS product_count
    FROM products
    GROUP BY Product_category, brand_name
),
category_avg_count AS (
    SELECT
		Product_category,
		AVG(product_count) AS avg_brand_count
    FROM brand_product_count
    GROUP BY Product_category
)
SELECT
    bpc.Product_category,
    bpc.brand_name,
    bpc.product_count,
    ROUND(cac.avg_brand_count, 2) AS avg_brand_count_in_category
FROM brand_product_count bpc
JOIN category_avg_count cac
    ON bpc.Product_category = cac.Product_category
WHERE bpc.product_count > cac.avg_brand_count
ORDER BY bpc.Product_category, bpc.product_count DESC;

#_________________________________________________________________________________________________________________________________________________#
#51. Find categories where total products exceed twice the average category size.
WITH category_count AS (
    SELECT
        Product_category,
        COUNT(*) AS product_count
    FROM products
    GROUP BY Product_category
),
overall_avg AS (
    SELECT AVG(product_count) AS avg_product_count
    FROM category_count
)
SELECT
    cc.Product_category,
    cc.product_count,
    ROUND(oa.avg_product_count, 2)      AS avg_category_count,
    ROUND(cc.product_count /
          oa.avg_product_count, 2)      AS times_avg
FROM category_count cc
CROSS JOIN overall_avg oa
WHERE cc.product_count > 2 * oa.avg_product_count
ORDER BY cc.product_count DESC;

#_________________________________________________________________________________________________________________________________________________#
#52. Find brands ranked in top 5 by revenue across multiple categories.
WITH brand_category_revenue AS (
    SELECT
        Product_category,
        brand_name,
        SUM(Revenue) AS total_revenue
    FROM products
    GROUP BY Product_category, brand_name
),
ranked AS (
    SELECT
        Product_category,
        brand_name,
        total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY Product_category
            ORDER BY total_revenue DESC
        ) AS rnk
    FROM brand_category_revenue
),
top5_per_category AS (
    SELECT
        brand_name,
        Product_category,
        total_revenue,
        rnk
    FROM ranked
    WHERE rnk <= 5
)
SELECT
    brand_name,
    COUNT(DISTINCT Product_category)    AS categories_in_top5,
    ROUND(SUM(total_revenue), 2)        AS total_revenue_across_categories
FROM top5_per_category
GROUP BY brand_name
HAVING COUNT(DISTINCT Product_category) > 1
ORDER BY categories_in_top5 DESC, total_revenue_across_categories DESC;

#_________________________________________________________________________________________________________________________________________________#
#53. Find categories whose revenue growth (cumulative) exceeds 80% before reaching top 10 products.
WITH category_total AS (
    SELECT
        Product_category,
        SUM(Revenue) AS total_revenue
    FROM products
    GROUP BY Product_category
),
product_ranked AS (
    SELECT
        p.Product_category,
        p.product_name,
        p.Revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.Product_category
            ORDER BY p.Revenue DESC
        ) AS rn
    FROM products p
),
cumulative AS (
    SELECT
        pr.Product_category,
        pr.product_name,
        pr.Revenue,
        pr.rn,
        SUM(pr.Revenue) OVER (
            PARTITION BY pr.Product_category
            ORDER BY pr.rn
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,
        ct.total_revenue
    FROM product_ranked pr
    JOIN category_total ct
        ON pr.Product_category = ct.Product_category
),
cumulative_pct AS (
    SELECT
        Product_category,
        product_name,
        rn,
        ROUND(Revenue, 2) AS Revenue,
        ROUND(cumulative_revenue, 2) AS cumulative_revenue,
        ROUND(cumulative_revenue * 100.0 / total_revenue, 2) AS cumulative_pct
    FROM cumulative
)
SELECT DISTINCT *
FROM cumulative_pct
WHERE rn <= 10
  AND cumulative_pct >= 80
ORDER BY Product_category;

#_________________________________________________________________________________________________________________________________________________#
#54. Find products whose revenue rank is better than their rating rank.
WITH ranked AS (
    SELECT
        product_name,
        brand_name,
        Product_category,
        Revenue,
        rating,
        DENSE_RANK() OVER (ORDER BY Revenue DESC) AS revenue_Rank,
        DENSE_RANK() OVER (ORDER BY rating  DESC) AS rating_Rank
    FROM products
)
SELECT
	revenue_Rank,
    product_name,
    brand_name,
    Product_category,
    ROUND(Revenue, 2)   AS Revenue,
    rating,
    rating_Rank,
    rating_rank - revenue_rank AS rank_gap
FROM ranked
WHERE revenue_rank < rating_rank
ORDER BY revenue_Rank;

#_________________________________________________________________________________________________________________________________________________#
#55. Find brands with highest product diversity across categories.
WITH brand_diversity AS (
    SELECT
        brand_name,
        COUNT(DISTINCT Product_category) AS category_count,
        COUNT(*) AS total_products,
        ROUND(SUM(Revenue), 2) AS total_revenue,
        ROUND(AVG(rating), 2) AS avg_rating
    FROM products
    GROUP BY brand_name
)
SELECT
	DENSE_RANK() OVER (
        ORDER BY category_count DESC
    ) AS diversity_rank,
    brand_name,
    category_count,
    total_products,
    total_revenue,
    avg_rating
FROM brand_diversity
ORDER BY category_count DESC, total_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#56. Find categories where top 3 brands contribute over 70% of revenue.
WITH brand_category_revenue AS (
    SELECT
        Product_category,
        brand_name,
        SUM(Revenue) AS brand_revenue
    FROM products
    GROUP BY Product_category, brand_name
),
category_total AS (
    SELECT
        Product_category,
        SUM(Revenue) AS total_category_revenue
    FROM products
    GROUP BY Product_category
),
ranked AS (
    SELECT
        bcr.Product_category,
        bcr.brand_name,
        bcr.brand_revenue,
        DENSE_RANK() OVER (
            PARTITION BY bcr.Product_category
            ORDER BY bcr.brand_revenue DESC
        ) AS rnk
    FROM brand_category_revenue bcr
),
top3_contribution AS (
    SELECT
        r.Product_category,
        SUM(r.brand_revenue)                                        AS top3_revenue,
        ct.total_category_revenue,
        ROUND(SUM(r.brand_revenue) * 100.0
              / ct.total_category_revenue, 2)                       AS top3_contribution_pct
    FROM ranked r
    JOIN category_total ct
        ON r.Product_category = ct.Product_category
    WHERE r.rnk <= 3
    GROUP BY r.Product_category, ct.total_category_revenue
)
SELECT
    Product_category,
    ROUND(top3_revenue, 2)          AS top3_revenue,
    ROUND(total_category_revenue, 2) AS total_category_revenue,
    top3_contribution_pct
FROM top3_contribution
WHERE top3_contribution_pct > 70
ORDER BY top3_contribution_pct;

#_________________________________________________________________________________________________________________________________________________#
#57. Find brands whose average revenue per product exceeds category average.
WITH brand_avg AS (
    SELECT
        Product_category,
        brand_name,
        AVG(Revenue) AS avg_brand_revenue
    FROM products
    GROUP BY Product_category, brand_name
),
category_avg AS (
    SELECT
        Product_category,
        AVG(Revenue) AS avg_category_revenue
    FROM products
    GROUP BY Product_category
)
SELECT
    ba.Product_category,
    ba.brand_name,
    ROUND(ba.avg_brand_revenue, 2)      AS avg_brand_revenue,
    ROUND(ca.avg_category_revenue, 2)   AS avg_category_revenue,
    ROUND(ba.avg_brand_revenue
          / ca.avg_category_revenue, 2) AS times_category_avg
FROM brand_avg ba
JOIN category_avg ca
    ON ba.Product_category = ca.Product_category
WHERE ba.avg_brand_revenue > ca.avg_category_revenue
ORDER BY ba.Product_category, ba.avg_brand_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#58. Find categories having both above-average revenue and above-average rating.
WITH overall_avg AS (
						SELECT
							AVG(Revenue) AS avg_revenue,
							AVG(rating)  AS avg_rating
						FROM products
),
category_stats AS (
					SELECT
						Product_category,
						AVG(Revenue) AS avg_category_revenue,
						AVG(rating)  AS avg_category_rating
					FROM products
					GROUP BY Product_category
)
SELECT
    cs.Product_category,
    ROUND(cs.avg_category_revenue, 2) AS avg_category_revenue,
    ROUND(cs.avg_category_rating, 2)  AS avg_category_rating,
    ROUND(oa.avg_revenue, 2) AS overall_avg_revenue,
    ROUND(oa.avg_rating, 2) AS overall_avg_rating
FROM category_stats cs
CROSS JOIN overall_avg oa
WHERE cs.avg_category_revenue > oa.avg_revenue
  AND cs.avg_category_rating  > oa.avg_rating
ORDER BY cs.avg_category_revenue DESC;

#_________________________________________________________________________________________________________________________________________________#
#59. Find products belonging to categories ranked in top 10 revenue categories.
WITH category_revenue AS (
    SELECT
        Product_category,
        SUM(Revenue) AS total_revenue
    FROM products
    GROUP BY Product_category
),
top10_categories AS (
    SELECT Product_category
    FROM category_revenue
    ORDER BY total_revenue DESC
    LIMIT 10
)
SELECT
    p.Product_category,
    p.product_name,
    p.brand_name,
    p.rating,
    ROUND(p.Revenue, 2) AS Revenue
FROM products p
JOIN top10_categories tc
    ON p.Product_category = tc.Product_category
ORDER BY p.Product_category, p.Revenue DESC;
